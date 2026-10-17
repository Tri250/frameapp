"""Validate the app's local policy metadata."""
from datetime import date


def validate_config(config):
    for key in ('operator', 'email', 'version'):
        if not isinstance(config.get(key), str) or not config[key].strip():
            raise ValueError(f'{key} must be a nonempty string')
    if '@' not in config['email'] or any(c.isspace() for c in config['email']):
        raise ValueError('email must be a contact address')
    date.fromisoformat(config['version'])
