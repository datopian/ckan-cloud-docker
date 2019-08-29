# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "ckan";
    .port = "5000";
}

sub vcl_backend_response {
    set beresp.grace = 1h;
    unset beresp.http.Server;
    # These status codes should always pass through and never cache.
    if ( beresp.status >= 500 ) {
        set beresp.ttl = 0s;
    }
    if (beresp.http.content-type ~ "(text|javascript|json|xml|html)") {
        set beresp.do_gzip = true;
    }
    # CKAN cache headers are used by Varnish cache, but should not be propagated to
    # the Internet. Tell browsers and proxies not to cache. This means Varnish always
    # gets the responsibility to server the right content at all times.
    if (beresp.http.Cache-Control ~ "max-age") {
        unset beresp.http.set-cookie;
        set beresp.http.Cache-Control = "no-cache";
    }

    # Encourage assets to be cached by proxies and browsers
    # JS and CSS may be gzipped depending on headers
    # see https://developers.google.com/speed/docs/best-practices/caching
    if (bereq.url ~ "\.(css|js)") {
        set beresp.http.Vary = "Accept-Encoding";
    }

    # Encourage assets to be cached by proxies and browsers for 1 day
    if (bereq.url ~ "\.(png|gif|jpg|swf|css|js)") {
        unset beresp.http.set-cookie;
        set beresp.http.Cache-Control = "public, max-age=86400";
        set beresp.ttl = 1d;
    }

    # Encourage CKAN vendor assets (which are versioned) to be cached by
    # by proxies and browsers for 1 year
    if (bereq.url ~ "^/scripts/vendor/") {
        unset beresp.http.set-cookie;
        set beresp.http.Cache-Control = "public, max-age=31536000";
        set beresp.ttl = 12m;
    }
    # # Never cache API requests
    # if (bereq.url ~ "^/api/") {
    #     set beresp.ttl = 0s;
    # }
}
sub vcl_recv {
    if (req.http.user-agent ~ "Ezooms" || req.http.user-agent ~ "Ahrefs") {
        return (synth(403));
    }
    if (req.url ~ "^/_tracking") {
        // exclude web spiders from statistics
        if (req.http.user-agent ~ "Googlebot" || req.http.user-agent ~ "baidu" || req.http.user-agent ~ "bing") {
            return (synth(200));
        } else {
            return (pass);
        }
    }
    if (req.url ~ "\.(png|gif|jpg|jpeg|swf|css|js|woff|eot)$") {
        //Varnish to deliver content from cache even if the request othervise indicates that the request should be passed
        return(hash);
    }

    // Remove has_js and Google Analytics cookies. Evan added sharethis cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(__[a-z]+|has_js|cookie-agreed-en|_csoot|_csuid|_chartbeat2)=[^;]*", "");

    // Remove a ";" prefix, if present.
    set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
    // Remove empty cookies.
    if (req.http.Cookie ~ "^\s*$") {
        unset req.http.Cookie;
    }

    unset req.http.X-Forwarded-For;
    set req.http.X-Forwarded-For = req.http.X-Real-IP;
} 

sub vcl_hash {
    # http://serverfault.com/questions/112531/ignoring-get-parameters-in-varnish-vcl
    hash_data(req.url);
    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }
    if (req.http.Cookie) {
        hash_data(req.http.Cookie);
    }
    if (req.http.Origin) {
        hash_data(req.http.Origin);
    }
}

sub vcl_deliver {
    if (!resp.http.Vary) {
        set resp.http.Vary = "Accept-Encoding";   
    } else if (resp.http.Vary !~ "(?i)Accept-Encoding") {
        set resp.http.Vary = resp.http.Vary + ",Accept-Encoding";
    }    
    unset resp.http.X-Varnish;
    unset resp.http.Via;
    unset resp.http.Age;
    unset resp.http.X-Powered-By;
}   

sub vcl_backend_error {
    unset beresp.http.Server;
    if (beresp.status == 751) {
        set beresp.http.Location = beresp.http.response;
        set beresp.status = 301;
        return (deliver);
    }
    if (beresp.status == 753) {
        set beresp.http.Location = beresp.http.response;
        set beresp.status = 301;
        return (deliver);
    }
}
