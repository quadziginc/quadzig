class UsersMailer < ActionMailer::Base

  def share_arch(url, email)
    @url = url

    mail(to: email,
            subject: "Quadzig Architecture Diagram",
            from: "Team Quadzig <share@quadzig.io>"
    ) do |format|
      format.text
      format.html
    end
  end

  def infrastructure_csv(url, email)
    @url = url

    mail(to: email,
            subject: "Quadzig Infrastructure Report",
            from: "Team Quadzig <share@quadzig.io>"
    ) do |format|
      format.text
      format.html
    end
  end
end
