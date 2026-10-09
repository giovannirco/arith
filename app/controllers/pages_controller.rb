# The page at /, read once from web/. Three files, no build step: edit
# web/index.html, web/style.css or web/app.js and restart.
class PagesController < ApplicationController
  WEB = Rails.root.join("web")
  INDEX = WEB.join("index.html").read.freeze
  STYLE = WEB.join("style.css").read.freeze
  SCRIPT = WEB.join("app.js").read.freeze

  # The page only loads its own stylesheet and script and only talks to this
  # origin. The header says so, which turns an injected script into a blocked
  # one.
  CONTENT_SECURITY_POLICY = "default-src 'none'; style-src 'self'; script-src 'self'; connect-src 'self'; " \
                            "img-src 'self' data:; form-action 'none'; base-uri 'none'; frame-ancestors 'none'".freeze

  def index
    response.headers["content-security-policy"] = CONTENT_SECURITY_POLICY
    response.headers["x-content-type-options"] = "nosniff"
    response.headers["referrer-policy"] = "no-referrer"
    render html: INDEX.html_safe
  end

  def style
    render plain: STYLE, content_type: "text/css"
  end

  def script
    render plain: SCRIPT, content_type: "text/javascript"
  end
end
