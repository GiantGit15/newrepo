class DevelopmentRedirect
  def initialize app
    @app = app
  end

  def call env
    if env["REQUEST_METHOD"] == "GET" && env["REQUEST_PATH"] =~ %r[\A/app/?\Z]
      redirect_to "/UI/index.html"
    else
      @app.call env
    end
  end

  def redirect_to path
    Rack::Response.new.tap do |resp|
      resp.redirect path
      resp.finish
    end
  end
end
