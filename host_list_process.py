import sys
import typing


class HostConfig:
    _hostname = ""
    _description = ""

    def __init__(self, host: str):
        self._host = host

    @property
    def hostname(self) -> str:
        return self._hostname or self._host

    def setHostname(self, hostname: str) -> "HostConfig":
        self._hostname = self._hostname or hostname
        return self

    @property
    def description(self) -> str:
        return f"\033[00;34m{self._description}\033[0m" if self._description else ""

    def setDescription(self, description: str) -> "HostConfig":
        self._description = self._description or description
        return self

    def __str__(self) -> str:
        return f"{self._host}|->|{self.hostname}|{self.description}"

    def __repr__(self):
        return str(vars(self))


def main(stdin: typing.TextIO):
    # @note should i print header here?
    # hosts: dict[str, HostConfig] = {"#": HostConfig("Alias").setHostname("Hostname").setDescription("Desc")} # }dict()
    hosts: dict[str, HostConfig] = dict()
    host_context = None

    def fetch_value(line: str) -> str:
        return line.split(maxsplit=1).pop(1)

    def get_host(host: str) -> "HostConfig":
        return hosts.setdefault(host, HostConfig(host))

    for line in stdin:
        line = line.rstrip().lower()

        if line.startswith("host "):
            host_context = [
                host
                for host in fetch_value(line).split()
                if not any(c in ["*", "?", "!"] for c in host)
            ]
            for host in host_context:
                get_host(host)
            continue

        # @todo should i implement 'Match' parsing?
        if line.startswith("match "):
            host_context = None
            continue

        if not host_context:
            continue

        for host in host_context:
            if line.startswith("hostname "):
                get_host(host).setHostname(fetch_value(line))
            if line.startswith("#_desc "):
                get_host(host).setDescription(fetch_value(line))

    return hosts.values()


if __name__ == "__main__":
    for host in main(sys.stdin):
        print(host)
        print(repr(host), file=sys.stderr)
