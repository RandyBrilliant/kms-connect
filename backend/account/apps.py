from django.apps import AppConfig


class AccountConfig(AppConfig):
    name = 'account'
    verbose_name = 'Account'

    def ready(self):
        from . import signals  # noqa: F401
