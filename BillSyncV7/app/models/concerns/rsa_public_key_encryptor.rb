# Encrypts with public RSA key stored in RSA_KEYPAIR .pem.
# Refer to MANAGING_RSA_KEYS for hints to learn how to provide keys.

module Concerns
  module RSAPublicKeyEncryptor
    extend ActiveSupport::Concern

    KEY = ENV["RSA_KEYPAIR"]

    class DirectAssignmentError < StandardError ; end

    module ClassMethods

      # Example given:
      #     class User
      #       encrypt :routing_number, :bank_name
      #     end
      def encrypt *args
        options, attribute_names = args.extract_options!, args
        attribute_names.each{ |name| redefine_accessors_for_encryption name, options }
      end

    private

      def redefine_accessors_for_encryption attribute_name, options
        encrypted_attribute_name = "encrypted_#{attribute_name}".to_sym
        obfuscate_method_name = "obfuscate_#{attribute_name}".to_sym

        define_method "#{attribute_name}=" do |value|
          if value.nil?
            self[encrypted_attribute_name] = value
            self[attribute_name] = value
            return
          end

          cipher = OpenSSL::PKey::RSA.new KEY
          encrypted = cipher.public_encrypt value

          if options[:obfuscate_with].present?
            obfuscated = options[:obfuscate_with].(value)
          else
            obfuscated = "###"
          end

          # Protect from accidental overwrites.  Quite limited, validations
          # would be great.  These are in frontend but not in backend.
          unless obfuscated == value
            self[encrypted_attribute_name] = encrypted
            self[attribute_name] = obfuscated
          end
        end

        define_method "#{encrypted_attribute_name}=" do |_value|
          message = "Cannot assign #{attribute_name} directly"
          raise DirectAssignmentError, message
        end

        define_method "serializable_hash_with_#{encrypted_attribute_name}" do |options = nil|
          options ||= {}
          (options[:except] ||= []) << encrypted_attribute_name.to_s
          send "serializable_hash_without_#{encrypted_attribute_name}", options
        end

        alias_method_chain "serializable_hash", encrypted_attribute_name
      end

    end

  end
end
