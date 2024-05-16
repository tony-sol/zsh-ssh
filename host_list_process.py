import sys

# @note 'Hostname' keyword outside `Match` or `Host` context is global
hostname = None


class HostConfig():
    _hostname = ''
    _description = ''

    def __init__(self, host):
        self._host = host

    @property
    def hostname(self) -> str:
        global hostname
        return hostname or self._hostname or self._host

    def setHostname(self, hostname: str) -> 'HostConfig':
        self._hostname = self._hostname or hostname
        return self

    @property
    def description(self) -> str:
        return f"[\033[00;34m{self._description}\033[0m]" \
            if self._description else ''

    def setDescription(self, description: str) -> 'HostConfig':
        self._description = self._description or description
        return self

    def __str__(self) -> str:
        return f"{self._host}|->|{self.hostname}|{self.description}"

    def __repr__(self):
        return str(vars(self))


def main(stdin):
    hosts = dict()
    host_context = None

    def fetch_value(line: str) -> str:
        return line.split(maxsplit=1).pop(1)

    def is_host_valid(host: str) -> bool:
        return all(c not in ['*', '?', '!'] for c in host)

    def get_host(host: str) -> 'HostConfig':
        return hosts.setdefault(host, HostConfig(host))

    for line in stdin:
        line = line.rstrip().lower()
        if line.startswith('host '):
            host_context = fetch_value(line).split()
            for host in host_context:
                if is_host_valid(host):
                    get_host(host)
        elif line.startswith('match '):
            pass
            # @todo implement 'Match' parsing

        if line.startswith('hostname '):
            if not host_context:
                global hostname
                hostname = hostname or fetch_value(line)
                continue
            for host in host_context:
                if is_host_valid(host):
                    get_host(host).setHostname(fetch_value(line))

        if line.startswith('#_desc '):
            if not host_context:
                continue
            for host in host_context:
                if is_host_valid(host):
                    get_host(host).setDescription(fetch_value(line))

    return hosts.values()


if __name__ == '__main__':
    for host in main(sys.stdin):
        print(host)
        print(repr(host), file=sys.stderr)
