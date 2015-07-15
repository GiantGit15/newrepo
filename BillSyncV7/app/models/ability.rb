class Ability
  include CanCan::Ability

  attr_reader :individual, :user, :appointment

  delegate :role, to: :appointment, allow_nil: true
  delegate :name, to: :role, prefix: true, allow_nil: true

  def initialize individual, user
    @individual = individual or return
    @user = user or return
    @appointment = individual.appointments.where(user_id: user.id).first
    apply_aliases
    apply_rules
    apply_rule_overrides
  end

  def permissions
    role.try(:permissions) || []
  end

  def apply_aliases
    # Override default REST aliases.  We want to customize them so this is
    # required.
    clear_aliased_actions
    alias_action :index, :show, :counts, :index_archived_invoices, :index_invoice_transactions, :to => :read
    alias_action :new, :batch_create, :to => :create
    alias_action :edit, :batch_update, :to => :update

    alias_action :create, :read, :update, :to => :cru
    alias_action :read_terms, :update_terms, :to => :manage_terms
    alias_action :read_accounting, :update_accounting, :to => :manage_accounting
  end

  def apply_rules
    permissions.each do |definition|
      perm = Permission[definition] or next
      can perm.action, perm.subject
    end

    apply_invoice_limits_on_amount_due
    apply_scoping_limits_on_expense_categories
    apply_scoping_limits_on_qb_classes
    apply_scoping_limits_on_vendors

    cannot :autorize, :payment if user && !user.verified?
  end

  # Rule overrides are for situations when they cannot be handled with aliases.
  # The most common example of it when we want to define ability with conditions
  # which cannot be simply reflected in +Permission+ model.
  def apply_rule_overrides
    if can?(:read_incomplete, Invoice) && !payer?
      # strangely, block form of #can is required.  Blame enums.
      can :read, Invoice, ["invoices.status IN (1,2,3,9,10)"] do |invoice|
        Invoice.statuses[invoice.status].in? [1,2,3,9,10]
      end
    end

    if clerk?
      cannot :manage, Invoice, ["invoices.status IN (4,5,6,7,8)"] do |invoice|
        Invoice.statuses[invoice.status].in? [4,5,6,7,8]
      end
    elsif payer?
      cannot :manage, Invoice, ["accountant_approved = false AND regular_approved = false"] do |invoice|
        ![invoice.regular_approved, invoice.accountant_approved].any?
      end
    end
  end

  def payer?
     role_name == "Payer"
  end

  def clerk?
     role_name == "Clerk"
  end

  # def role_name
  #   role.try(:name)
  # end

  # Permission constraints set for particular individuals.
  def apply_invoice_limits_on_amount_due
    {
      individual.limit_min => :<,
      individual.limit_max => :>,
    }.each do |limit, disallowance_operator|
      next if limit.nil?
      sql = "(amount_due IS NOT NULL) AND (amount_due #{disallowance_operator} ?)"

      cannot :manage, Invoice, [sql, limit] do |obj|
        obj.amount_due.present? && obj.amount_due.send(disallowance_operator, limit)
      end
    end
  end

  def apply_scoping_limits_on_expense_categories
    allowed_account_ids = individual.permitted_expense_accounts.pluck(:id)
    apply_scoping_limit Invoice, :expense_account_id, allowed_account_ids
    apply_scoping_limit LineItem, :expense_account_id, allowed_account_ids
  end

  def apply_scoping_limits_on_qb_classes
    allowed_qb_class_ids = individual.permitted_qb_classes.pluck(:id)
    apply_scoping_limit Invoice, :qb_class_id, allowed_qb_class_ids
  end

  def apply_scoping_limits_on_vendors
    allowed_vendor_ids = individual.permitted_vendors.pluck(:id)
    apply_scoping_limit Invoice, :vendor_id, allowed_vendor_ids
    apply_scoping_limit Vendor, :id, allowed_vendor_ids
  end

  def apply_scoping_limit model, column, allowed_ids
    if allowed_ids.present?
      sql = ["#{column} NOT IN (?)", allowed_ids]
      cannot :manage, model, sql do |obj|
        not obj.send(column).in? allowed_ids
      end
    end
  end
end
