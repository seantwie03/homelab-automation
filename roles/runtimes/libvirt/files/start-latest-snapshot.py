#!/usr/bin/python3
"""Revert libvirt domains on qemu:///system to their newest snapshot and start them.

Changes made since that snapshot are discarded. A snapshot taken while the
domain was running resumes where it left off; one taken while it was shut off
boots fresh.
"""

import argparse
import sys
import xml.etree.ElementTree as ET
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Self

import libvirt

PROG = Path(sys.argv[0]).name
URI = "qemu:///system"

EPILOG = """\
The last line of output summarizes which domains succeeded and failed.

exit status:
    0  every domain succeeded
    1  one or more domains failed
    2  usage error
"""


class SnapshotError(Exception):
    """A domain cannot be reverted for a reason libvirt itself does not report."""


def log(message: str) -> None:
    print(message, flush=True)


def warn(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def ignore_libvirt_error(*_: object) -> None:
    """Stops libvirt printing errors itself; they still raise libvirtError."""


@dataclass(frozen=True, slots=True, kw_only=True)
class Snapshot:
    handle: libvirt.virDomainSnapshot
    name: str
    created: datetime

    @classmethod
    def load(cls, handle: libvirt.virDomainSnapshot) -> Self:
        """Reads the creation time from the snapshot XML."""
        root = ET.fromstring(text=handle.getXMLDesc())
        try:
            created = int(root.findtext(path="creationTime", default=""))
        except ValueError:
            raise SnapshotError(f"Invalid creation time for snapshot: {handle.getName()}") from None
        return cls(
            handle=handle,
            name=handle.getName(),
            created=datetime.fromtimestamp(timestamp=created).astimezone(),
        )


def restore_latest_snapshot(domain: libvirt.virDomain, *, dry_run: bool) -> None:
    """Reverts DOMAIN to its newest snapshot and starts it, or only reports it with DRY_RUN."""
    snapshots = [Snapshot.load(handle=handle) for handle in domain.listAllSnapshots()]
    if not snapshots:
        raise SnapshotError(f"No snapshots found for {domain.name()}")

    latest = max(snapshots, key=lambda snapshot: snapshot.created)
    if dry_run:
        log(message=f"Would restore {domain.name()} to snapshot {latest.name} and start it")
        return

    # Changes made since this snapshot will be discarded.
    log(message=f"Restoring {domain.name()} to snapshot {latest.name} and starting it")
    domain.revertToSnapshot(snap=latest.handle, flags=libvirt.VIR_DOMAIN_SNAPSHOT_REVERT_RUNNING)


def restore_all(conn: libvirt.virConnect, names: Sequence[str], *, dry_run: bool) -> int:
    """Processes every domain in NAMES, continuing past failures. Returns the exit status."""
    succeeded: list[str] = []
    failed: list[str] = []

    for name in names:
        log(message=f"\nProcessing {name}")
        try:
            restore_latest_snapshot(domain=conn.lookupByName(name=name), dry_run=dry_run)
        except (libvirt.libvirtError, SnapshotError) as error:
            warn(message=str(object=error))
            warn(message=f"Failed to process {name}; continuing.")
            failed.append(name)
        else:
            succeeded.append(name)

    label = "would restore" if dry_run else "restored"
    log(message=f"\n{label}: {' '.join(succeeded) or 'none'}; failed: {' '.join(failed) or 'none'}")
    return 1 if failed else 0


@dataclass(frozen=True, slots=True, kw_only=True)
class Args:
    domains: tuple[str, ...]
    all: bool
    dry_run: bool


def parse_args(argv: Sequence[str] | None = None) -> Args:
    """Parses the arguments. Exits with status 2 on an error."""
    parser = argparse.ArgumentParser(
        prog=PROG,
        description=__doc__,
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="show the snapshot each domain would be reverted to without changing anything",
    )
    targets = parser.add_mutually_exclusive_group()
    targets.add_argument("-a", "--all", action="store_true", help="process every defined domain")
    targets.add_argument("domains", nargs="*", default=[], metavar="DOMAIN", help="libvirt domain name")
    namespace = parser.parse_args(args=argv)
    args = Args(domains=tuple(namespace.domains), all=namespace.all, dry_run=namespace.dry_run)
    if not args.all and not args.domains:
        parser.error(message="pass one or more DOMAIN names or --all")
    return args


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv=argv)
    libvirt.registerErrorHandler(f=ignore_libvirt_error, ctx=None)

    try:
        conn = libvirt.open(name=URI)
    except libvirt.libvirtError as error:
        warn(message=f"{PROG}: {error}")
        return 1

    with conn:
        if args.all:
            try:
                names = sorted(domain.name() for domain in conn.listAllDomains())
            except libvirt.libvirtError as error:
                warn(message=f"{PROG}: {error}")
                return 1
            if not names:
                log(message="No domains found.")
                return 0
        else:
            names = args.domains

        try:
            return restore_all(conn=conn, names=names, dry_run=args.dry_run)
        except KeyboardInterrupt:
            return 130


if __name__ == "__main__":
    sys.exit(main())
