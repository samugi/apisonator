module ThreeScale
  module Backend
    module Validators
      class RedirectUrl < Base
        # This should've been named redirect_uri as per OAuth specs, but was
        # initially named redirect_url. We check both fields, prioritizing the
        # contents in the legacy redirect_url parameter over the "new"
        # redirect_uri one.
        REDIRECT_URL = 'redirect_url'.freeze
        REDIRECT_URI = 'redirect_uri'.freeze

        def apply
          invalid_exception = RedirectURIInvalid
          redirect_uri = if params.has_key? REDIRECT_URL
                           invalid_exception = RedirectURLInvalid
                           params[REDIRECT_URL]
                         else
                           params[REDIRECT_URI]
                         end
          if redirect_uri.nil? || redirect_uri.empty? || application.redirect_url == redirect_uri
            succeed!
          else
            fail!(invalid_exception.new redirect_uri)
          end
        end
      end
    end
  end
end
