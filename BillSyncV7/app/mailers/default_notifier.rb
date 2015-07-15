class DefaultNotifier < ActionMailer::Base

  def send_signatures(files)
    files.each do |file|
      hash = {
        content_type: "image/jpg",
        content: file[:file]
      }
      attachments[file[:filename]] = hash
    end

    puts ">>> #{attachments.inspect}"

    mail(
      to: ["vijay@bill-sync.com", "danielfromarg@gmail.com"],
      from: "notifications@bill-sync.com",
      body: '',
      subject: "#{Rails.env} - New signatures",
    )
  end

  def new_comment(comment)
    @comment = comment
    hit = Hit.find_by(mt_hit_id: comment.mt_hit_id)
    mail(
      to: "projectscottyalto@gmail.com",
      from: "notifications@bill-sync.com",
      subject: "[#{Rails.env}][#{comment.mt_worker_id}] #{hit.title}"
    )
  end

  def send_worker_message(subject, body)
    mail(
      to: "projectscottyalto@gmail.com",
      from: "notifications@bill-sync.com",
      subject: subject,
      body: body
    )
  end

end
