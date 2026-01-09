class SubdomainMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        host = request.get_host().split(":")[0]

        # Split host into parts
        parts = host.split(".")

        # demo.localhost → ["demo", "localhost"]
        if len(parts) > 1:
            request.subdomain = parts[0]
        else:
            request.subdomain = None

        return self.get_response(request)
