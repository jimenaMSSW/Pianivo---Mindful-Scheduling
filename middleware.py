# core/middleware.py

class SubdomainMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        host = request.get_host().split('.')
        # Simple logic: take first part as subdomain
        request.subdomain = host[0] if len(host) > 2 else None
        return self.get_response(request)
