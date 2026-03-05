from django.apps import AppConfig


class MainConfig(AppConfig):
    name = 'main'

    def ready(self):
        from . import signals  # noqa: F401  – register application status signals
