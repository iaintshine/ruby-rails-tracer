class ArticleMailer < ApplicationMailer
  def notify_new_article
    mail(to: 'xeviknal@unknown.com', subject: 'Subject')
  end
end
