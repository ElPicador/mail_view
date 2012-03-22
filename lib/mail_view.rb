require 'erb'
require 'tilt'

require 'rack/mime'

class MailView
  autoload :Mapper, 'mail_view/mapper'

  class << self
    def default_email_template_path
      File.expand_path('../mail_view/email.html.erb', __FILE__)
    end

    def default_index_template_path
      File.expand_path('../mail_view/index.html.erb', __FILE__)
    end

    def call(env)
      new.call(env)
    end
  end

  def call(env)
    path_info = env["PATH_INFO"]

    if path_info == "" || path_info == "/"
      links = self.actions.sort.map do |action|
        [action, "#{env["SCRIPT_NAME"]}/#{action}"]
      end

      ok index_template.render(Object.new, :links => links)
    elsif path_info =~ /([\w_]+)(\.\w+)?$/
      name   = $1
      format = $2 || ".html"

      if actions.include?(name)
        ok render_mail(name, send(name), format)
      else
        not_found
      end
    else
      not_found(true)
    end
  end

  protected
    def actions
      public_methods(false).map(&:to_s) - ['call']
    end

    def email_template
      Tilt.new(email_template_path)
    end

    def email_template_path
      self.class.default_email_template_path
    end

    def index_template
      Tilt.new(index_template_path)
    end

    def index_template_path
      self.class.default_index_template_path
    end

  private
    def ok(body)
      locale = nil
      if lang = env["HTTP_ACCEPT_LANGUAGE"]
        lang = lang.split(",").map { |l|
          l += ';q=1.0' unless l =~ /;q=\d+\.\d+$/
          l.split(';q=')
        }.first
        locale = lang.first.split("-").first
      else
        locale = I18n.default_locale
      end

      locale = env['rack.locale'] = I18n.locale = locale.to_s
      [200, {"Content-Type" => "text/html", 'Content-Language' => locale}, [body]]
    end

    def not_found(pass = false)
      if pass
        [404, {"Content-Type" => "text/html", "X-Cascade" => "pass"}, ["Not Found"]]
      else
        [404, {"Content-Type" => "text/html"}, ["Not Found"]]
      end
    end

    def render_mail(name, mail, format = nil)
      body_part = mail

      if mail.multipart?
        content_type = Rack::Mime.mime_type(format)
        content_type = %r{text\/html|multipart\/related} if content_type == 'text/html'
        body_part = mail.parts.find { |part| part.content_type.match(content_type) } || mail.parts.first
      end

      email_template.render(Object.new, :name => name, :mail => mail, :body_part => body_part)
    end

end
