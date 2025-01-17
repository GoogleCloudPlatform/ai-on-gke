#!/usr/bin/env python3

# Copyright (C) SchedMD LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from typing import Iterable, List, Tuple, Optional, Any, Dict
import argparse
import base64
import collections
from dataclasses import dataclass
import hashlib
import inspect
import json
import logging
import logging.config
import math
import os
import re
import shelve
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
from enum import Enum
from collections import defaultdict, namedtuple
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import contextmanager
from functools import lru_cache, reduce, wraps
from itertools import chain, islice
from pathlib import Path
from time import sleep, time

import slurm_gcp_plugins

from google.cloud import secretmanager
from google.cloud import storage

import google.auth  # noqa: E402
from google.oauth2 import service_account  # noqa: E402
import googleapiclient.discovery  # noqa: E402
import google_auth_httplib2  # noqa: E402
from googleapiclient.http import set_user_agent  # noqa: E402
from google.api_core.client_options import ClientOptions  # noqa: E402
import httplib2  # noqa: E402

try:
    from google.cloud import tpu_v2 as tpu  # noqa: E402
    can_tpu = True
except ImportError: # TODO: remove once CentOS 7 is deprecated or dependency is added
    f"WARNING: Missing Python module 'google.cloud.tpu_v2 (pip:google-cloud-tpu)', TPU support will not work."
    can_tpu = False

import google.api_core.exceptions as gExceptions  # noqa: E402

from requests import get as get_url  # noqa: E402
from requests.exceptions import RequestException  # noqa: E402

import yaml  # noqa: E402
from addict import Dict as NSDict  # noqa: E402


USER_AGENT = "Slurm_GCP_Scripts/1.5 (GPN:SchedMD)"
ENV_CONFIG_YAML = os.getenv("SLURM_CONFIG_YAML")
if ENV_CONFIG_YAML:
    CONFIG_FILE = Path(ENV_CONFIG_YAML)
else:
    CONFIG_FILE = Path(__file__).with_name("config.yaml")
API_REQ_LIMIT = 2000


def mkdirp(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


scripts_dir = next(
    p for p in (Path(__file__).parent, Path("/slurm/scripts")) if p.is_dir()
)


# load all directories as Paths into a dict-like namespace
dirs = NSDict(
    {
        n: Path(p)
        for n, p in dict.items(
            {
                "home": "/home",
                "apps": "/opt/apps",
                "slurm": "/slurm",
                "scripts": scripts_dir,
                "custom_scripts": "/slurm/custom_scripts",
                "munge": "/etc/munge",
                "secdisk": "/mnt/disks/sec",
                "log": "/var/log/slurm",
            }
        )
    }
)

slurmdirs = NSDict(
    {
        n: Path(p)
        for n, p in dict.items(
            {
                "prefix": "/usr/local",
                "etc": "/usr/local/etc/slurm",
                "state": "/var/spool/slurm",
            }
        )
    }
)


yaml.SafeDumper.yaml_representers[
    None
] = lambda self, data: yaml.representer.SafeRepresenter.represent_str(self, str(data))


class ApiEndpoint(Enum):
    COMPUTE = "compute"
    BQ = "bq"
    STORAGE = "storage"
    TPU = "tpu"
    SECRET = "secret_manager"


@lru_cache(maxsize=1)
def default_credentials():
    return google.auth.default()[0]


@lru_cache(maxsize=1)
def authentication_project():
    return google.auth.default()[1]


DEFAULT_UNIVERSE_DOMAIN = "googleapis.com"


def universe_domain() -> str:
    try:
        return instance_metadata("attributes/universe_domain")
    except Exception:
        return DEFAULT_UNIVERSE_DOMAIN


def endpoint_version(api: ApiEndpoint) -> Optional[str]:
    return lookup().endpoint_versions.get(api.value, None)


@lru_cache(maxsize=1)
def get_credentials() -> Optional[service_account.Credentials]:
    """Get credentials for service account"""
    key_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if key_path is not None:
        credentials = service_account.Credentials.from_service_account_file(
            key_path, scopes=[f"https://www.{universe_domain()}/auth/cloud-platform"]
        )
    else:
        credentials = default_credentials()

    return credentials


def create_client_options(api: ApiEndpoint) -> ClientOptions:
    """Create client options for cloud endpoints"""
    ver = endpoint_version(api)
    ud = universe_domain()
    options = {}
    if ud and ud != DEFAULT_UNIVERSE_DOMAIN:
        options["universe_domain"] = ud
    if ver:
        options["api_endpoint"] = f"https://{api.value}.{ud}/{ver}/"
    co = ClientOptions(**options)
    log.debug(f"Using ClientOptions = {co} for API: {api.value}")
    return co

log = logging.getLogger()


def access_secret_version(project_id, secret_id, version_id="latest"):
    """
    Access the payload for the given secret version if one exists. The version
    can be a version number as a string (e.g. "5") or an alias (e.g. "latest").
    """
    co = create_client_options(ApiEndpoint.SECRET)
    client = secretmanager.SecretManagerServiceClient(client_options=co)
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"
    try:
        response = client.access_secret_version(request={"name": name})
        log.debug(f"Secret '{name}' was found.")
        payload = response.payload.data.decode("UTF-8")
    except gExceptions.NotFound:
        log.debug(f"Secret '{name}' was not found!")
        payload = None

    return payload


def parse_self_link(self_link: str):
    """Parse a selfLink url, extracting all useful values
    https://.../v1/projects/<project>/regions/<region>/...
    {'project': <project>, 'region': <region>, ...}
    can also extract zone, instance (name), image, etc
    """
    link_patt = re.compile(r"(?P<key>[^\/\s]+)s\/(?P<value>[^\s\/]+)")
    return NSDict(link_patt.findall(self_link))


def parse_bucket_uri(uri: str):
    """
    Parse a bucket url
    E.g. gs://<bucket_name>/<path>
    """
    pattern = re.compile(r"gs://(?P<bucket>[^/\s]+)/(?P<path>([^/\s]+)(/[^/\s]+)*)")
    matches = pattern.match(uri)
    return matches.group("bucket"), matches.group("path")


def trim_self_link(link: str):
    """get resource name from self link url, eg.
    https://.../v1/projects/<project>/regions/<region>
    -> <region>
    """
    try:
        return link[link.rindex("/") + 1 :]
    except ValueError:
        raise Exception(f"'/' not found, not a self link: '{link}' ")


def execute_with_futures(func, seq):
    with ThreadPoolExecutor() as exe:
        futures = []
        for i in seq:
            future = exe.submit(func, i)
            futures.append(future)
        for future in as_completed(futures):
            result = future.exception()
            if result is not None:
                raise result


def map_with_futures(func, seq):
    with ThreadPoolExecutor() as exe:
        futures = []
        for i in seq:
            future = exe.submit(func, i)
            futures.append(future)
        for future in futures:
            # Will be result or raise Exception
            res = None
            try:
                res = future.result()
            except Exception as e:
                res = e
            yield res

def _get_bucket_and_common_prefix() -> Tuple[str, str]:
    uri = instance_metadata("attributes/slurm_bucket_path")
    return parse_bucket_uri(uri)

def blob_get(file):
    bucket_name, path = _get_bucket_and_common_prefix()
    blob_name = f"{path}/{file}"
    return storage_client().get_bucket(bucket_name).blob(blob_name)


def blob_list(prefix="", delimiter=None):
    bucket_name, path = _get_bucket_and_common_prefix()
    blob_prefix = f"{path}/{prefix}"
    # Note: The call returns a response only when the iterator is consumed.
    blobs = storage_client().list_blobs(
        bucket_name, prefix=blob_prefix, delimiter=delimiter
    )
    return [blob for blob in blobs]


def hash_file(fullpath: Path) -> str:
    with open(fullpath, "rb") as f:
        file_hash = hashlib.md5()
        chunk = f.read(8192)
        while chunk:
            file_hash.update(chunk)
            chunk = f.read(8192)
    return base64.b64encode(file_hash.digest()).decode("utf-8")


def install_custom_scripts(check_hash=False):
    """download custom scripts from gcs bucket"""

    compute_tokens = ["compute", "prolog", "epilog"]
    if lookup().instance_role == "compute":
        try:
            compute_tokens.append(f"nodeset-{lookup().node_nodeset_name()}")
        except Exception as e:
            log.error(f"Failed to lookup nodeset: {e}")

    prefix_tokens = dict.get(
        {
            "login": ["login"],
            "compute": compute_tokens,
            "controller": ["controller", "prolog", "epilog"],
        },
        lookup().instance_role,
        [],
    )
    prefixes = [f"slurm-{tok}-script" for tok in prefix_tokens]
    blobs = list(chain.from_iterable(blob_list(prefix=p) for p in prefixes))

    script_pattern = re.compile(r"slurm-(?P<path>\S+)-script-(?P<name>\S+)")
    for blob in blobs:
        m = script_pattern.match(Path(blob.name).name)
        if not m:
            log.warning(f"found blob that doesn't match expected pattern: {blob.name}")
            continue
        path_parts = m["path"].split("-")
        path_parts[0] += ".d"
        stem, _, ext = m["name"].rpartition("_")
        filename = ".".join((stem, ext))

        path = Path(*path_parts, filename)
        fullpath = (dirs.custom_scripts / path).resolve()
        mkdirp(fullpath.parent)

        for par in path.parents:
            chown_slurm(dirs.custom_scripts / par)
        need_update = True
        if check_hash and fullpath.exists():
            # TODO: MD5 reported by gcloud may differ from the one calculated here (e.g. if blob got gzipped),
            # consider using gCRC32C
            need_update = hash_file(fullpath) != blob.md5_hash
        if need_update:
            log.info(f"installing custom script: {path} from {blob.name}")
            with fullpath.open("wb") as f:
                blob.download_to_file(f)
            chown_slurm(fullpath, mode=0o755)

def compute_service(version="beta"):
    """Make thread-safe compute service handle
    creates a new Http for each request
    """
    credentials = get_credentials()

    def build_request(http, *args, **kwargs):
        new_http = set_user_agent(httplib2.Http(), USER_AGENT)
        if credentials is not None:
            new_http = google_auth_httplib2.AuthorizedHttp(credentials, http=new_http)
        return googleapiclient.http.HttpRequest(new_http, *args, **kwargs)

    ver = endpoint_version(ApiEndpoint.COMPUTE)
    disc_url = googleapiclient.discovery.DISCOVERY_URI
    if ver:
        version = ver
        disc_url = disc_url.replace(DEFAULT_UNIVERSE_DOMAIN, universe_domain())

    log.debug(f"Using version={version} of Google Compute Engine API")
    return googleapiclient.discovery.build(
        "compute",
        version,
        requestBuilder=build_request,
        credentials=credentials,
        discoveryServiceUrl=disc_url,
    )

def storage_client() -> storage.Client:
    """
    Config-independent storage client
    """
    ud = universe_domain()
    co = {}
    if ud and ud != DEFAULT_UNIVERSE_DOMAIN:
        co["universe_domain"] = ud
    return storage.Client(client_options=ClientOptions(**co))


class DeffetiveStoredConfigError(Exception):
    """
    Raised when config can not be loaded and assembled from bucket
    """
    pass


def _fill_cfg_defaults(cfg: NSDict) -> NSDict:
    if not cfg.slurm_log_dir:
        cfg.slurm_log_dir = dirs.log
    if not cfg.slurm_bin_dir:
        cfg.slurm_bin_dir = slurmdirs.prefix / "bin"
    if not cfg.slurm_control_host:
        cfg.slurm_control_host = f"{cfg.slurm_cluster_name}-controller"
    if not cfg.slurm_control_host_port:
        cfg.slurm_control_host_port = "6820-6830"
    if not cfg.munge_mount: # NOTE: should only happen with cloud controller
        cfg.munge_mount = NSDict(
            {
                "server_ip": cfg.slurm_control_addr or cfg.slurm_control_host,
                "remote_mount": "/etc/munge",
                "fs_type": "nfs",
                "mount_options": "defaults,hard,intr,_netdev",
            }
        )
    
    network_storage_iter = filter(
        None,
        (
            cfg.munge_mount,
            *cfg.network_storage,
            *cfg.login_network_storage,
            *chain.from_iterable(ns.network_storage for ns in cfg.nodeset.values()),
            *chain.from_iterable(ns.network_storage for ns in cfg.nodeset_dyn.values()),
            *chain.from_iterable(ns.network_storage for ns in cfg.nodeset_tpu.values()),
        ),
    )
    for netstore in network_storage_iter:
        if netstore != "gcsfuse" and (
            netstore.server_ip is None or netstore.server_ip == "$controller"
        ):
            netstore.server_ip = cfg.slurm_control_host
    return cfg

def _list_config_blobs() -> Tuple[Any, str]:
    _, common_prefix = _get_bucket_and_common_prefix()
    res = { # TODO: use a dataclass once we move to python 3.7
        "core": None,
        "partition": [],
        "nodeset": [],
        "nodeset_dyn": [],
        "nodeset_tpu": [],
    }
    hash = hashlib.md5()
    blobs = list(blob_list(prefix=""))
    # sort blobs so hash is consistent
    for blob in sorted(blobs, key=lambda b: b.name):
        if blob.name == f"{common_prefix}/config.yaml":
            res["core"] = blob
            hash.update(blob.md5_hash.encode("utf-8"))
        for key in ("partition", "nodeset", "nodeset_dyn", "nodeset_tpu"):
            if blob.name.startswith(f"{common_prefix}/{key}_configs/"):
                res[key].append(blob)
                hash.update(blob.md5_hash.encode("utf-8"))

    if res["core"] is None:
        raise DeffetiveStoredConfigError("config.yaml not found in bucket")
    return res, hash.hexdigest()
        

def _fetch_config(old_hash: Optional[str]) -> Optional[Tuple[NSDict, str]]:
    """Fetch config from bucket, returns None if no changes are detected."""
    blobs, hash = _list_config_blobs()
    if old_hash == hash:
        return None

    def _download(bs) -> List[Any]:
        return [yaml.safe_load(b.download_as_text()) for b in bs]

    return _assemble_config(
        core=_download([blobs["core"]])[0],
        partitions=_download(blobs["partition"]),
        nodesets=_download(blobs["nodeset"]),
        nodesets_dyn=_download(blobs["nodeset_dyn"]),
        nodesets_tpu=_download(blobs["nodeset_tpu"]),
    ), hash

def _assemble_config(
        core: Any, 
        partitions: List[Any], 
        nodesets: List[Any],
        nodesets_dyn: List[Any],
        nodesets_tpu: List[Any],
    ) -> NSDict:
    cfg = NSDict(core)

    # add partition configs
    for p_yaml in partitions:
        p_cfg = NSDict(p_yaml)
        assert p_cfg.get("partition_name"), "partition_name is required"
        p_name = p_cfg.partition_name
        assert p_name not in cfg.partitions, f"partition {p_name} already defined"
        cfg.partitions[p_name] = p_cfg

    # add nodeset configs
    ns_names = set()
    def _add_nodesets(yamls: List[Any], target: dict):
        for ns_yaml in yamls:
            ns_cfg = NSDict(ns_yaml)
            assert ns_cfg.get("nodeset_name"), "nodeset_name is required"
            ns_name = ns_cfg.nodeset_name
            assert ns_name not in ns_names, f"nodeset {ns_name} already defined"
            target[ns_name] = ns_cfg
            ns_names.add(ns_name)

    _add_nodesets(nodesets, cfg.nodeset)
    _add_nodesets(nodesets_dyn, cfg.nodeset_dyn)
    _add_nodesets(nodesets_tpu, cfg.nodeset_tpu)

    # validate that configs for all referenced nodesets are present
    for p in cfg.partitions.values():
        for ns_name in chain(p.partition_nodeset, p.partition_nodeset_dyn, p.partition_nodeset_tpu):
            if ns_name not in ns_names:
                raise DeffetiveStoredConfigError(f"nodeset {ns_name} not defined in config")
        
    return _fill_cfg_defaults(cfg)

def fetch_config() -> Tuple[bool, NSDict]:
    """
    Fetches config from bucket and saves it locally 
    Returns True if new (updated) config was fetched
    """
    hash_file = Path("/slurm/scripts/.config.hash")
    old_hash = hash_file.read_text() if hash_file.exists() else None
    
    cfg_and_hash = _fetch_config(old_hash=old_hash)
    if not cfg_and_hash:
        return False, _load_config()

    cfg, hash = cfg_and_hash
    hash_file.write_text(hash)
    chown_slurm(hash_file)
    CONFIG_FILE.write_text(yaml.dump(cfg, Dumper=Dumper))
    chown_slurm(CONFIG_FILE)
    return True, cfg

def owned_file_handler(filename):
    """create file handler"""
    chown_slurm(filename)
    return logging.handlers.WatchedFileHandler(filename, delay=True)

def get_log_path() -> Path:
    """
    Returns path to log file for the current script.
    e.g. resume.py -> /var/log/slurm/resume.log
    """
    cfg_log_dir = lookup().cfg.slurm_log_dir
    log_dir = Path(cfg_log_dir) if cfg_log_dir else dirs.log
    return (log_dir / Path(sys.argv[0]).name).with_suffix(".log")

def init_log_and_parse(parser: argparse.ArgumentParser) -> argparse.Namespace:
    parser.add_argument(
        "--debug",
        "-d",
        dest="loglevel",
        action="store_const",
        const=logging.DEBUG,
        default=logging.INFO,
        help="Enable debugging output",
    )
    parser.add_argument(
        "--trace-api",
        "-t",
        action="store_true",
        help="Enable detailed api request output",
    )
    args = parser.parse_args()
    loglevel = args.loglevel
    if lookup().cfg.enable_debug_logging:
        loglevel = logging.DEBUG
    if args.trace_api:
        lookup().cfg.extra_logging_flags["trace_api"] = True
    # Configure root logger
    logging.config.dictConfig({
        "version": 1,
        "disable_existing_loggers": True,
        "formatters": {
            "standard": {
                "format": "%(levelname)s: %(message)s",
            },
            "stamp": {
                "format": "%(asctime)s %(levelname)s: %(message)s",
            },
        },
        "handlers": {
            "stdout_handler": {
                "level": logging.DEBUG,
                "formatter": "standard",
                "class": "logging.StreamHandler",
                "stream": sys.stdout,
            },
            "file_handler": {
                "()": owned_file_handler,
                "level": logging.DEBUG,
                "formatter": "stamp",
                "filename": get_log_path(),
            },
        },
        "root": {
            "handlers": ["stdout_handler", "file_handler"],
            "level": loglevel,
        },
    })

    sys.excepthook = _handle_exception

    return args


def log_api_request(request):
    """log.trace info about a compute API request"""
    if not lookup().cfg.extra_logging_flags.get("trace_api"):
        return
    # output the whole request object as pretty yaml
    # the body is nested json, so load it as well
    rep = json.loads(request.to_json())
    if rep.get("body", None) is not None:
        rep["body"] = json.loads(rep["body"])
    pretty_req = yaml.safe_dump(rep).rstrip()
    # label log message with the calling function
    log.debug(f"{inspect.stack()[1].function}:\n{pretty_req}")


def _handle_exception(exc_type, exc_value, exc_trace):
    """log exceptions other than KeyboardInterrupt"""
    if not issubclass(exc_type, KeyboardInterrupt):
        log.exception("Fatal exception", exc_info=(exc_type, exc_value, exc_trace))
    sys.__excepthook__(exc_type, exc_value, exc_trace)


def run(
    args,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    shell=False,
    timeout=None,
    check=True,
    universal_newlines=True,
    **kwargs,
):
    """Wrapper for subprocess.run() with convenient defaults"""
    if isinstance(args, list):
        args = list(filter(lambda x: x is not None, args))
        args = " ".join(args)
    if not shell and isinstance(args, str):
        args = shlex.split(args)
    log.debug(f"run: {args}")
    result = subprocess.run(
        args,
        stdout=stdout,
        stderr=stderr,
        shell=shell,
        timeout=timeout,
        check=check,
        universal_newlines=universal_newlines,
        **kwargs,
    )
    return result


def chown_slurm(path: Path, mode=None) -> None:
    if path.exists():
        if mode:
            path.chmod(mode)
    else:
        mkdirp(path.parent)
        if mode:
            path.touch(mode=mode)
        else:
            path.touch()
    try:
        shutil.chown(path, user="slurm", group="slurm")
    except LookupError:
        log.warning(f"User 'slurm' does not exist. Cannot 'chown slurm:slurm {path}'.")
    except PermissionError:
        log.warning(f"Not authorized to 'chown slurm:slurm {path}'.")
    except Exception as err:
        log.error(err)


@contextmanager
def cd(path):
    """Change working directory for context"""
    prev = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(prev)


def cached_property(f):
    return property(lru_cache()(f))


def retry(max_retries: int, init_wait_time: float, warn_msg: str, exc_type: Exception):
    """Retries functions that raises the exception exc_type.
    Retry time is increased by a factor of two for every iteration.

    Args:
        max_retries (int): Maximum number of retries
        init_wait_time (float): Initial wait time in secs
        warn_msg (str): Message to print during retries
        exc_type (Exception): Exception type to check for
    """

    if max_retries <= 0:
        raise ValueError("Incorrect value for max_retries, must be >= 1")
    if init_wait_time <= 0.0:
        raise ValueError("Invalid value for init_wait_time, must be > 0.0")

    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            retry = 0
            secs = init_wait_time
            captured_exc = None
            while retry < max_retries:
                try:
                    return f(*args, **kwargs)
                except exc_type as e:
                    captured_exc = e
                    log.warn(f"{warn_msg}, retrying in {secs}")
                    sleep(secs)
                    retry += 1
                    secs *= 2
            raise captured_exc

        return wrapper

    return decorator


def separate(pred, coll):
    """filter into 2 lists based on pred returning True or False
    returns ([False], [True])
    """
    return reduce(lambda acc, el: acc[pred(el)].append(el) or acc, coll, ([], []))


def chunked(iterable, n=API_REQ_LIMIT):
    """group iterator into chunks of max size n"""
    it = iter(iterable)
    while True:
        chunk = list(islice(it, n))
        if not chunk:
            return
        yield chunk


def groupby_unsorted(seq, key):
    indices = defaultdict(list)
    for i, el in enumerate(seq):
        indices[key(el)].append(i)
    for k, idxs in indices.items():
        yield k, (seq[i] for i in idxs)


@lru_cache(maxsize=32)
def find_ratio(a, n, s, r0=None):
    """given the start (a), count (n), and sum (s), find the ratio required"""
    if n == 2:
        return s / a - 1
    an = a * n
    if n == 1 or s == an:
        return 1
    if r0 is None:
        # we only need to know which side of 1 to guess, and the iteration will work
        r0 = 1.1 if an < s else 0.9

    # geometric sum formula
    def f(r):
        return a * (1 - r**n) / (1 - r) - s

    # derivative of f
    def df(r):
        rm1 = r - 1
        rn = r**n
        return (a * (rn * (n * rm1 - r) + r)) / (r * rm1**2)

    MIN_DR = 0.0001  # negligible change
    r = r0
    # print(f"r(0)={r0}")
    MAX_TRIES = 64
    for i in range(1, MAX_TRIES + 1):
        try:
            dr = f(r) / df(r)
        except ZeroDivisionError:
            log.error(f"Failed to find ratio due to zero division! Returning r={r0}")
            return r0
        r = r - dr
        # print(f"r({i})={r}")
        # if the change in r is small, we are close enough
        if abs(dr) < MIN_DR:
            break
    else:
        log.error(f"Could not find ratio after {MAX_TRIES}! Returning r={r0}")
        return r0
    return r


def backoff_delay(start, timeout=None, ratio=None, count: int = 0):
    """generates `count` waits starting at `start`
    sum of waits is `timeout` or each one is `ratio` bigger than the last
    the last wait is always 0"""
    # timeout or ratio must be set but not both
    assert (timeout is None) ^ (ratio is None)
    assert ratio is None or ratio > 0
    assert timeout is None or timeout >= start
    assert (count > 1 or timeout is not None) and isinstance(count, int)
    assert start > 0

    if count == 0:
        # Equation for auto-count is tuned to have a max of
        # ~int(timeout) counts with a start wait of <0.01.
        # Increasing start wait decreases count eg.
        # backoff_delay(10, timeout=60) -> count = 5
        count = int(
            (timeout / ((start + 0.05) ** (1 / 2)) + 2) // math.log(timeout + 2)
        )

    yield start
    # if ratio is set:
    # timeout = start * (1 - ratio**(count - 1)) / (1 - ratio)
    if ratio is None:
        ratio = find_ratio(start, count - 1, timeout)

    wait = start
    # we have start and 0, so we only need to generate count - 2
    for _ in range(count - 2):
        wait *= ratio
        yield wait
    yield 0
    return


ROOT_URL = "http://metadata.google.internal/computeMetadata/v1"


def get_metadata(path, root=ROOT_URL):
    """Get metadata relative to metadata/computeMetadata/v1"""
    HEADERS = {"Metadata-Flavor": "Google"}
    url = f"{root}/{path}"
    try:
        resp = get_url(url, headers=HEADERS)
        resp.raise_for_status()
        return resp.text
    except RequestException:
        log.debug(f"metadata not found ({url})")
        raise Exception(f"failed to get_metadata from {url}")


@lru_cache(maxsize=None)
def instance_metadata(path):
    """Get instance metadata"""
    return get_metadata(path, root=f"{ROOT_URL}/instance")


@lru_cache(maxsize=None)
def project_metadata(key):
    """Get project metadata project/attributes/<slurm_cluster_name>-<path>"""
    return get_metadata(key, root=f"{ROOT_URL}/project/attributes")


def bucket_blob_download(bucket_name, blob_name):
    bucket = storage_client().bucket(bucket_name)
    blob = bucket.blob(blob_name)
    contents = None
    with tempfile.NamedTemporaryFile(mode="w+t") as tmp:
        blob.download_to_filename(tmp.name)
        with open(tmp.name, "r") as f:
            contents = f.read()
    return contents


def natural_sort(text):
    def atoi(text):
        return int(text) if text.isdigit() else text

    return [atoi(w) for w in re.split(r"(\d+)", text)]

# TODO: replace with to_hostlist_fast
def to_hostlist(nodenames) -> str:
    """make hostlist from list of node names"""
    # use tmp file because list could be large
    tmp_file = tempfile.NamedTemporaryFile(mode="w+t", delete=False)
    tmp_file.writelines("\n".join(sorted(nodenames, key=natural_sort)))
    tmp_file.close()

    hostlist = run(f"{lookup().scontrol} show hostlist {tmp_file.name}").stdout.rstrip()
    os.remove(tmp_file.name)
    return hostlist


def to_hostlist_fast(names: Iterable[str]) -> str:
    """
    Fast implementation of to_hostlist that doesn't invoke `scontrol`
    IMPORTANT:
    * Acts as `scontrol show hostlistsorted`, i.e. original order is not preserved
    * Achieves worse compression than `to_hostlist` for some cases
    """
    pref = defaultdict(list)
    tokenizer = re.compile(r"^(.*?)(\d*)$")
    for name in filter(None, names):
        p, s = tokenizer.match(name).groups()
        pref[p].append(s)

    def _compress_suffixes(ss: List[str]) -> List[str]:
        cur, res = None, []

        def cur_repr():
            nums, strs = cur
            if nums[0] == nums[1]:
                return strs[0]
            return f"{strs[0]}-{strs[1]}"

        for s in sorted(ss, key=int):
            n = int(s)
            if cur is None:
                cur = ((n, n), (s, s))
                continue

            nums, strs = cur
            if n == nums[1] + 1:
                cur = ((nums[0], n), (strs[0], s))
            else:
                res.append(cur_repr())
                cur = ((n, n), (s, s))
        if cur:
            res.append(cur_repr())
        return res

    res = []
    for p in sorted(pref.keys()):
        sl = defaultdict(list)
        for s in pref[p]:
            sl[len(s)].append(s)
        cs = []
        for ln in sorted(sl.keys()):
            if ln == 0:
                res.append(p)
            else:
                cs.extend(_compress_suffixes(sl[ln]))
        if not cs:
            continue
        if len(cs) == 1 and "-" not in cs[0]:
            res.append(f"{p}{cs[0]}")
        else:
            res.append(f"{p}[{','.join(cs)}]")
    return ",".join(res)


def part_is_tpu(part):
    """check if partition with name part contains a nodeset of type tpu"""
    return len(lookup().cfg.partitions[part].partition_nodeset_tpu) > 0

def to_hostnames(nodelist: str) -> List[str]:
    """make list of hostnames from hostlist expression"""
    if not nodelist:
        return []  # avoid degenerate invocation of scontrol
    if isinstance(nodelist, str):
        hostlist = nodelist
    else:
        hostlist = ",".join(nodelist)
    hostnames = run(f"{lookup().scontrol} show hostnames {hostlist}").stdout.splitlines()
    return hostnames


def retry_exception(exc):
    """return true for exceptions that should always be retried"""
    retry_errors = (
        "Rate Limit Exceeded",
        "Quota Exceeded",
    )
    return any(e in str(exc) for e in retry_errors)


def ensure_execute(request):
    """Handle rate limits and socket time outs"""

    for retry, wait in enumerate(backoff_delay(0.5, timeout=10 * 60, count=20)):
        try:
            return request.execute()
        except googleapiclient.errors.HttpError as e:
            if retry_exception(e):
                log.error(f"retry:{retry} '{e}'")
                sleep(wait)
                continue
            raise

        except socket.timeout as e:
            # socket timed out, try again
            log.debug(e)

        except Exception as e:
            log.error(e, exc_info=True)
            raise

        break


def batch_execute(requests, retry_cb=None, log_err=log.error):
    """execute list or dict<req_id, request> as batch requests
    retry if retry_cb returns true
    """
    BATCH_LIMIT = 1000
    if not isinstance(requests, dict):
        requests = {str(k): v for k, v in enumerate(requests)}  # rid generated here
    done = {}
    failed = {}
    timestamps = []
    rate_limited = False

    def batch_callback(rid, resp, exc):
        nonlocal rate_limited
        if exc is not None:
            log_err(f"compute request exception {rid}: {exc}")
            if retry_exception(exc):
                rate_limited = True
            else:
                req = requests.pop(rid)
                failed[rid] = (req, exc)
        else:
            # if retry_cb is set, don't move to done until it returns false
            if retry_cb is None or not retry_cb(resp):
                requests.pop(rid)
                done[rid] = resp

    def batch_request(reqs):
        batch = lookup().compute.new_batch_http_request(callback=batch_callback)
        for rid, req in reqs:
            batch.add(req, request_id=rid)
        return batch

    while requests:
        if timestamps:
            timestamps = [stamp for stamp in timestamps if stamp > time()]
        if rate_limited and timestamps:
            stamp = next(iter(timestamps))
            sleep(max(stamp - time(), 0))
            rate_limited = False
        # up to API_REQ_LIMIT (2000) requests
        # in chunks of up to BATCH_LIMIT (1000)
        batches = [
            batch_request(chunk)
            for chunk in chunked(islice(requests.items(), API_REQ_LIMIT), BATCH_LIMIT)
        ]
        timestamps.append(time() + 100)
        with ThreadPoolExecutor() as exe:
            futures = []
            for batch in batches:
                future = exe.submit(ensure_execute, batch)
                futures.append(future)
            for future in futures:
                result = future.exception()
                if result is not None:
                    raise result

    return done, failed


def wait_request(operation, project: str):
    """makes the appropriate wait request for a given operation"""
    if "zone" in operation:
        req = lookup().compute.zoneOperations().wait(
            project=project,
            zone=trim_self_link(operation["zone"]),
            operation=operation["name"],
        )
    elif "region" in operation:
        req = lookup().compute.regionOperations().wait(
            project=project,
            region=trim_self_link(operation["region"]),
            operation=operation["name"],
        )
    else:
        req = lookup().compute.globalOperations().wait(
            project=project, operation=operation["name"]
        )
    return req


def wait_for_operation(operation):
    """wait for given operation"""
    project = parse_self_link(operation["selfLink"]).project
    wait_req = wait_request(operation, project=project)

    while True:
        result = ensure_execute(wait_req)
        if result["status"] == "DONE":
            log_errors = " with errors" if "error" in result else ""
            log.debug(
                f"operation complete{log_errors}: type={result['operationType']}, name={result['name']}"
            )
            return result


def wait_for_operations(operations):
    return [
        wait_for_operation(op) for op in operations
    ]


def get_filtered_operations(op_filter):
    """get list of operations associated with group id"""
    project = lookup().project
    operations = []

    def get_aggregated_operations(items):
        # items is a dict of location key to value: dict(operations=<list of operations>) or an empty dict
        operations.extend(
            chain.from_iterable(
                ops["operations"] for ops in items.values() if "operations" in ops
            )
        )

    act = lookup().compute.globalOperations()
    op = act.aggregatedList(
        project=project, filter=op_filter, fields="items.*.operations,nextPageToken"
    )

    while op is not None:
        result = ensure_execute(op)
        get_aggregated_operations(result["items"])
        op = act.aggregatedList_next(op, result)
    return operations


def get_insert_operations(group_ids):
    """get all insert operations from a list of operationGroupId"""
    if isinstance(group_ids, str):
        group_ids = group_ids.split(",")
    filters = [
        "operationType=insert",
        " OR ".join(f"(operationGroupId={id})" for id in group_ids),
    ]
    return get_filtered_operations(" AND ".join(f"({f})" for f in filters if f))


def machine_type_family(mt: str) -> str:
    """get machine type family from machine type"""
    # TODO: doesn't work with N1 custom machine types
    # See https://cloud.google.com/compute/docs/instances/creating-instance-with-custom-machine-type#create
    return mt.split("-")[0]


def machine_type_sockets(template) -> int:
    guestCpus: int = int(template.machine_info.guestCpus)
    return {
        "h3": 2,
        "c2d": 2 if guestCpus > 56 else 1,
        "a3": 2,
    }.get(
        machine_type_family(template.machineType),
        1,  # assume 1 socket for all other families
    )


def isSmt(template) -> bool:
    # https://cloud.google.com/compute/docs/cpu-platforms
    noSmtFamily = ("t2a", "t2d", "h3",)
    if machine_type_family(template.machineType) in noSmtFamily:
        return False
    if template.machine_info.guestCpus == 1:
        return False
    return True


def getThreadsPerCore(template) -> int:
    if not isSmt(template):
        return 1
    return template.advancedMachineFeatures.threadsPerCore or 2


@retry(
    max_retries=9,
    init_wait_time=1,
    warn_msg="Temporary failure in name resolution",
    exc_type=socket.gaierror,
)
def host_lookup(host_name: str) -> str:
    return socket.gethostbyname(host_name)


class Dumper(yaml.SafeDumper):
    """Add representers for pathlib.Path and NSDict for yaml serialization"""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.add_representer(NSDict, self.represent_nsdict)
        self.add_multi_representer(Path, self.represent_path)

    @staticmethod
    def represent_nsdict(dumper, data):
        return dumper.represent_mapping("tag:yaml.org,2002:map", data.items())

    @staticmethod
    def represent_path(dumper, path):
        return dumper.represent_scalar("tag:yaml.org,2002:str", str(path))


class TPU:
    """Class for handling the TPU-vm nodes"""

    if can_tpu:
        State = tpu.types.cloud_tpu.Node.State
        TPUS_PER_VM = 4
        __expected_states = {
            "create": State.READY,
            "start": State.READY,
            "stop": State.STOPPED,
        }

        __tpu_version_mapping = {
            "V2": tpu.AcceleratorConfig().Type.V2,
            "V3": tpu.AcceleratorConfig().Type.V3,
            "V4": tpu.AcceleratorConfig().Type.V4,
        }

    def __init__(self, nodeset):
        if not can_tpu:
            raise Exception("TPU pip package not installed")
        self._nodeset = nodeset
        self._parent = f"projects/{lookup().project}/locations/{nodeset.zone}"
        co = create_client_options(ApiEndpoint.TPU)
        self._client = tpu.TpuClient(client_options=co)
        self.data_disks = []
        for data_disk in nodeset.data_disks:
            ad = tpu.AttachedDisk()
            ad.source_disk = data_disk
            ad.mode = tpu.AttachedDisk.DiskMode.DISK_MODE_UNSPECIFIED
            self.data_disks.append(ad)
        ns_ac = nodeset.accelerator_config
        if ns_ac.topology != "" and ns_ac.version != "":
            ac = tpu.AcceleratorConfig()
            ac.topology = ns_ac.topology
            ac.type_ = self.__tpu_version_mapping[ns_ac.version]
            self.ac = ac
        else:
            req = tpu.GetAcceleratorTypeRequest(
                name=f"{self._parent}/acceleratorTypes/{nodeset.node_type}"
            )
            self.ac = self._client.get_accelerator_type(req).accelerator_configs[0]
        self.vmcount = self.__calc_vm_from_topology(self.ac.topology)

    @property
    def nodeset(self):
        return self._nodeset

    @property
    def preserve_tpu(self):
        return self._nodeset.preserve_tpu

    @property
    def node_type(self):
        return self._nodeset.node_type

    @property
    def tf_version(self):
        return self._nodeset.tf_version

    @property
    def enable_public_ip(self):
        return self._nodeset.enable_public_ip

    @property
    def preemptible(self):
        return self._nodeset.preemptible

    @property
    def reserved(self):
        return self._nodeset.reserved

    @property
    def service_account(self):
        return self._nodeset.service_account

    @property
    def zone(self):
        return self._nodeset.zone

    def check_node_type(self):
        if self.node_type is None:
            return False
        try:
            request = tpu.GetAcceleratorTypeRequest(
                name=f"{self._parent}/acceleratorTypes/{self.node_type}"
            )
            return self._client.get_accelerator_type(request=request) is not None
        except Exception:
            return False

    def check_tf_version(self):
        try:
            request = tpu.GetRuntimeVersionRequest(
                name=f"{self._parent}/runtimeVersions/{self.tf_version}"
            )
            return self._client.get_runtime_version(request=request) is not None
        except Exception:
            return False

    def __calc_vm_from_topology(self, topology):
        topo = topology.split("x")
        tot = 1
        for num in topo:
            tot = tot * int(num)
        return tot // self.TPUS_PER_VM

    def __check_resp(self, response, op_name):
        des_state = self.__expected_states.get(op_name)
        # If the state is not in the table just print the response
        if des_state is None:
            return False
        if response.__class__.__name__ != "Node":  # If the response is not a node fail
            return False
        if response.state == des_state:
            return True
        return False

    def list_nodes(self):
        try:
            request = tpu.ListNodesRequest(parent=self._parent)
            res = self._client.list_nodes(request=request)
        except gExceptions.NotFound:
            res = None
        return res

    def list_node_names(self):
        return [node.name.split("/")[-1] for node in self.list_nodes()]

    def start_node(self, nodename):
        request = tpu.StartNodeRequest(name=f"{self._parent}/nodes/{nodename}")
        resp = self._client.start_node(request=request).result()
        return self.__check_resp(resp, "start")

    def stop_node(self, nodename):
        request = tpu.StopNodeRequest(name=f"{self._parent}/nodes/{nodename}")
        resp = self._client.stop_node(request=request).result()
        return self.__check_resp(resp, "stop")

    def get_node(self, nodename):
        try:
            request = tpu.GetNodeRequest(name=f"{self._parent}/nodes/{nodename}")
            res = self._client.get_node(request=request)
        except gExceptions.NotFound:
            res = None
        return res

    def _register_node(self, nodename, ip_addr):
        dns_name = socket.getnameinfo((ip_addr, 0), 0)[0]
        run(
            f"{lookup().scontrol} update nodename={nodename} nodeaddr={ip_addr} nodehostname={dns_name}"
        )

    def create_node(self, nodename):
        if self.vmcount > 1 and not isinstance(nodename, list):
            log.error(
                f"Tried to create a {self.vmcount} node TPU on nodeset {self._nodeset.nodeset_name} but only received one nodename {nodename}"
            )
            return False
        if self.vmcount > 1 and (
            isinstance(nodename, list) and len(nodename) != self.vmcount
        ):
            log.error(
                f"Expected to receive a list of {self.vmcount} nodenames for TPU node creation in nodeset {self._nodeset.nodeset_name}, but received this list {nodename}"
            )
            return False

        node = tpu.Node()
        node.accelerator_config = self.ac
        node.runtime_version = f"tpu-vm-tf-{self.tf_version}"
        startup_script = """
        #!/bin/bash
        echo "startup script not found > /var/log/startup_error.log"
        """
        with open(
            Path(lookup().cfg.slurm_scripts_dir or dirs.scripts) / "startup.sh", "r"
        ) as script:
            startup_script = script.read()
        if isinstance(nodename, list):
            node_id = nodename[0]
            slurm_names = []
            wid = 0
            for node_wid in nodename:
                slurm_names.append(f"WORKER_{wid}:{node_wid}")
                wid += 1
        else:
            node_id = nodename
            slurm_names = [f"WORKER_0:{nodename}"]
        node.metadata = {
            "slurm_docker_image": self.nodeset.docker_image,
            "startup-script": startup_script,
            "slurm_instance_role": "compute",
            "slurm_cluster_name": lookup().cfg.slurm_cluster_name,
            "slurm_bucket_path": lookup().cfg.bucket_path,
            "slurm_names": ";".join(slurm_names),
            "universe_domain": universe_domain(),
        }
        node.tags = [lookup().cfg.slurm_cluster_name]
        if self.nodeset.service_account:
            node.service_account.email = self.nodeset.service_account.email
            node.service_account.scope = self.nodeset.service_account.scopes
        node.scheduling_config.preemptible = self.preemptible
        node.scheduling_config.reserved = self.reserved
        node.network_config.subnetwork = self.nodeset.subnetwork
        node.network_config.enable_external_ips = self.enable_public_ip
        if self.data_disks:
            node.data_disks = self.data_disks

        request = tpu.CreateNodeRequest(parent=self._parent, node=node, node_id=node_id)
        resp = self._client.create_node(request=request).result()
        if not self.__check_resp(resp, "create"):
            return False
        if isinstance(nodename, list):
            for node_id, net_endpoint in zip(nodename, resp.network_endpoints):
                self._register_node(node_id, net_endpoint.ip_address)
        else:
            ip_add = resp.network_endpoints[0].ip_address
            self._register_node(nodename, ip_add)
        return True

    def delete_node(self, nodename):
        request = tpu.DeleteNodeRequest(name=f"{self._parent}/nodes/{nodename}")
        try:
            resp = self._client.delete_node(request=request).result()
            if resp:
                return self.get_node(nodename=nodename) is None
            return False
        except gExceptions.NotFound:
            # log only error if vmcount is 1 as for other tpu vm count, this could be "phantom" nodes
            if self.vmcount == 1:
                log.error(f"Tpu single node {nodename} not found")
            else:
                # for the TPU nodes that consist in more than one vm, only the first node of the TPU a.k.a. the master node will
                # exist as real TPU nodes, so the other ones are expected to not be found, check the hostname of the node that has
                # not been found, and if it ends in 0, it means that is the master node and it should have been found, and in consequence
                # log an error
                nodehostname = yaml.safe_load(
                    run(f"{lookup().scontrol} --yaml show node {nodename}").stdout.rstrip()
                )["nodes"][0]["hostname"]
                if nodehostname.split("-")[-1] == "0":
                    log.error(f"TPU master node {nodename} not found")
                else:
                    log.info(f"Deleted TPU 'phantom' node {nodename}")
            # If the node is not found it is tecnichally deleted, so return success.
            return True


@dataclass(frozen=True)
class ReservationDetails:
    project: str
    zone: str
    name: str
    policies: List[str] # names (not URLs) of resource policies
    bulk_insert_name: str # name in format suitable for bulk insert (currently identical to user supplied name in long format)

class Lookup:
    """Wrapper class for cached data access"""

    def __init__(self, cfg):
        self._cfg = cfg
        self.template_cache_path = Path(__file__).parent / "template_info.cache"

    @property
    def cfg(self):
        return self._cfg

    @property
    def project(self):
        return self.cfg.project or authentication_project()

    @property
    def control_addr(self):
        return self.cfg.slurm_control_addr

    @property
    def control_host(self):
        return self.cfg.slurm_control_host

    @cached_property
    def control_host_addr(self):
        return host_lookup(self.cfg.slurm_control_host)

    @property
    def control_host_port(self):
        return self.cfg.slurm_control_host_port

    @property
    def endpoint_versions(self):
        return self.cfg.endpoint_versions

    @property
    def scontrol(self):
        return Path(self.cfg.slurm_bin_dir or "") / "scontrol"

    @cached_property
    def instance_role(self):
        return instance_metadata("attributes/slurm_instance_role")

    @cached_property
    def instance_role_safe(self):
        try:
            role = self.instance_role
        except Exception as e:
            log.error(e)
            role = None
        return role

    @property
    def is_controller(self):
        return self.instance_role_safe == "controller"

    @cached_property
    def compute(self):
        # TODO evaluate when we need to use google_app_cred_path
        if self.cfg.google_app_cred_path:
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = self.cfg.google_app_cred_path
        return compute_service()

    @cached_property
    def hostname(self):
        return socket.gethostname()

    @cached_property
    def hostname_fqdn(self):
        return socket.getfqdn()

    @cached_property
    def zone(self):
        return instance_metadata("zone")

    node_desc_regex = re.compile(
        r"^(?P<prefix>(?P<cluster>[^\s\-]+)-(?P<nodeset>\S+))-(?P<node>(?P<suffix>\w+)|(?P<range>\[[\d,-]+\]))$"
    )

    @lru_cache(maxsize=None)
    def _node_desc(self, node_name):
        """Get parts from node name"""
        if not node_name:
            node_name = self.hostname
        # workaround below is for VMs whose hostname is FQDN
        node_name_short = node_name.split(".")[0]
        m = self.node_desc_regex.match(node_name_short)
        if not m:
            raise Exception(f"node name {node_name} is not valid")
        return m.groupdict()

    def node_prefix(self, node_name=None):
        return self._node_desc(node_name)["prefix"]

    def node_nodeset_name(self, node_name=None):
        return self._node_desc(node_name)["nodeset"]

    def node_nodeset(self, node_name=None):
        nodeset_name = self.node_nodeset_name(node_name)
        ns = self.cfg.nodeset.get(nodeset_name)
        if ns:
            return ns
        return self.cfg.nodeset_tpu.get(nodeset_name)

    def node_is_tpu(self, node_name=None):
        nodeset_name = self.node_nodeset_name(node_name)
        return self.cfg.nodeset_tpu.get(nodeset_name) is not None

    def node_is_dyn(self, node_name=None) -> bool:
        nodeset = self.node_nodeset_name(node_name)
        return self.cfg.nodeset_dyn.get(nodeset) is not None

    def chunk_tpu_nodes(self, tpu_nodes):
        model = tpu_nodes[0]
        tpu = TPU(self.node_nodeset(model))
        return chunked(tpu_nodes, n=tpu.vmcount)

    def node_template(self, node_name=None):
        return self.node_nodeset(node_name).instance_template

    def node_template_info(self, node_name=None):
        return self.template_info(self.node_template(node_name))

    def node_region(self, node_name=None):
        nodeset = self.node_nodeset(node_name)
        return parse_self_link(nodeset.subnetwork).region

    def nodeset_prefix(self, nodeset_name):
        return f"{self.cfg.slurm_cluster_name}-{nodeset_name}"

    def nodelist_range(self, nodeset_name: str, start: int, count: int) -> str:
        assert 0 <= start and 0 < count
        pref = self.nodeset_prefix(nodeset_name)
        if count == 1:
            return f"{pref}-{start}"
        return f"{pref}-[{start}-{start + count - 1}]"

    def static_dynamic_sizes(self, nodeset: object) -> int:
        return (nodeset.node_count_static or 0, nodeset.node_count_dynamic_max or 0)

    def nodelist(self, nodeset) -> str:
        cnt = sum(self.static_dynamic_sizes(nodeset))
        if cnt == 0:
            return ""
        return self.nodelist_range(nodeset.nodeset_name, 0, cnt)

    def nodenames(self, nodeset) -> Tuple[Iterable[str], Iterable[str]]:
        pref = self.nodeset_prefix(nodeset.nodeset_name)
        s_count, d_count = self.static_dynamic_sizes(nodeset)
        return (
            (f"{pref}-{i}" for i in range(s_count)),
            (f"{pref}-{i}" for i in range(s_count, s_count + d_count)),
        )

    def power_managed_nodesets(self) -> Iterable[object]:
        return chain(self.cfg.nodeset.values(), self.cfg.nodeset_tpu.values())

    def is_power_managed_node(self, node_name: str) -> bool:
        try:
            ns = self.node_nodeset(node_name)
            if ns is None:
                return False
            idx = int(self._node_desc(node_name)["suffix"])
            return idx < sum(self.static_dynamic_sizes(ns))
        except Exception:
            return False

    def is_static_node(self, node_name: str) -> bool:
        if not self.is_power_managed_node(node_name):
            return False
        idx = int(self._node_desc(node_name)["suffix"])
        return idx < self.node_nodeset(node_name).node_count_static

    @lru_cache(maxsize=None)
    def slurm_nodes(self):
        StateTuple = namedtuple("StateTuple", "base,flags")

        def make_node_tuple(node_line):
            """turn node,state line to (node, StateTuple(state))"""
            # state flags include: CLOUD, COMPLETING, DRAIN, FAIL, POWERED_DOWN,
            #   POWERING_DOWN
            node, fullstate = node_line.split(",")
            state = fullstate.split("+")
            state_tuple = StateTuple(state[0], set(state[1:]))
            return (node, state_tuple)

        cmd = (
            f"{self.scontrol} show nodes | "
            r"grep -oP '^NodeName=\K(\S+)|\s+State=\K(\S+)' | "
            r"paste -sd',\n'"
        )
        node_lines = run(cmd, shell=True).stdout.rstrip().splitlines()
        nodes = {
            node: state
            for node, state in map(make_node_tuple, node_lines)
            if "CLOUD" in state.flags or "DYNAMIC_NORM" in state.flags
        }
        return nodes

    def slurm_node(self, nodename):
        return self.slurm_nodes().get(nodename)

    @lru_cache(maxsize=1)
    def instances(self) -> Dict[str, object]:
        instance_information_fields = [
            "advancedMachineFeatures",
            "cpuPlatform",
            "creationTimestamp",
            "disks",
            "disks",
            "fingerprint",
            "guestAccelerators",
            "hostname",
            "id",
            "kind",
            "labelFingerprint",
            "labels",
            "lastStartTimestamp",
            "lastStopTimestamp",
            "lastSuspendedTimestamp",
            "machineType",
            "metadata",
            "name",
            "networkInterfaces",
            "resourceStatus",
            "scheduling",
            "selfLink",
            "serviceAccounts",
            "shieldedInstanceConfig",
            "shieldedInstanceIntegrityPolicy",
            "sourceMachineImage",
            "status",
            "statusMessage",
            "tags",
            "zone",
            # "deletionProtection",
            # "startRestricted",
        ]
        if lookup().cfg.enable_slurm_gcp_plugins:
            slurm_gcp_plugins.register_instance_information_fields(
                lkp=lookup(),
                project=self.project,
                slurm_cluster_name=self.cfg.slurm_cluster_name,
                instance_information_fields=instance_information_fields,
            )

        # TODO: Merge this with all fields when upcoming maintenance is
        # supported in beta.
        if endpoint_version(ApiEndpoint.COMPUTE) == 'alpha':
          instance_information_fields.append("upcomingMaintenance")

        instance_information_fields = sorted(set(instance_information_fields))
        instance_fields = ",".join(instance_information_fields)
        fields = f"items.zones.instances({instance_fields}),nextPageToken"
        flt = f"labels.slurm_cluster_name={self.cfg.slurm_cluster_name} AND name:{self.cfg.slurm_cluster_name}-*"
        act = self.compute.instances()
        op = act.aggregatedList(project=self.project, fields=fields, filter=flt)

        def properties(inst):
            """change instance properties to a preferred format"""
            inst["zone"] = trim_self_link(inst["zone"])
            inst["machineType"] = trim_self_link(inst["machineType"])
            # metadata is fetched as a dict of dicts like:
            # {'key': key, 'value': value}, kinda silly
            metadata = {i["key"]: i["value"] for i in inst["metadata"].get("items", [])}
            if "slurm_instance_role" not in metadata:
                return None
            inst["role"] = metadata["slurm_instance_role"]
            inst["metadata"] = metadata
            # del inst["metadata"]  # no need to store all the metadata
            return NSDict(inst)

        instances = {}
        while op is not None:
            result = ensure_execute(op)
            instance_iter = (
                (inst["name"], properties(inst))
                for inst in chain.from_iterable(
                    zone.get("instances", []) for zone in result.get("items", {}).values()
                )
            )
            instances.update(
                {name: props for name, props in instance_iter if props is not None}
            )
            op = act.aggregatedList_next(op, result)
        return instances

    def instance(self, instance_name: str) -> Optional[object]:
        return self.instances().get(instance_name)

    @lru_cache()
    def _get_reservation(self, project: str, zone: str, name: str) -> object:
        """See https://cloud.google.com/compute/docs/reference/rest/v1/reservations"""
        return self.compute.reservations().get(
            project=project, zone=zone, reservation=name).execute()
    
    def nodeset_reservation(self, nodeset: object) -> Optional[ReservationDetails]:
        if not nodeset.reservation_name:
            return None
        
        zones = list(nodeset.zone_policy_allow or [])
        assert len(zones) == 1, "Only single zone is supported if using a reservation"
        zone = zones[0]

        regex = re.compile(r'^projects/(?P<project>[^/]+)/reservations/(?P<reservation>[^/]+)(/.*)?$')
        if not (match := regex.match(nodeset.reservation_name)):
            raise ValueError(
                f"Invalid reservation name: '{nodeset.reservation_name}', expected format is 'projects/PROJECT/reservations/NAME'"
            )
        
        project, name = match.group("project", "reservation")
        reservation = self._get_reservation(project, zone, name)

        # Converts policy URLs to names, e.g.:
        # projects/111111/regions/us-central1/resourcePolicies/zebra -> zebra
        policies = [u.split("/")[-1] for u in reservation.get("resourcePolicies", {}).values()]

        return ReservationDetails(
            project=project,
            zone=zone,
            name=name,
            policies=policies,
            bulk_insert_name=nodeset.reservation_name)

    @lru_cache(maxsize=1)
    def machine_types(self):
        field_names = "name,zone,guestCpus,memoryMb,accelerators"
        fields = f"items.zones.machineTypes({field_names}),nextPageToken"

        machines = defaultdict(dict)
        act = self.compute.machineTypes()
        op = act.aggregatedList(project=self.project, fields=fields)
        while op is not None:
            result = ensure_execute(op)
            machine_iter = chain.from_iterable(
                scope.get("machineTypes", []) for scope in result["items"].values()
            )
            for machine in machine_iter:
                name = machine["name"]
                zone = machine["zone"]
                machines[name][zone] = machine

            op = act.aggregatedList_next(op, result)
        return machines

    def machine_type(self, machine_type: str):
        """ """
        custom_patt = re.compile(
            r"((?P<family>\w+)-)?custom-(?P<cpus>\d+)-(?P<mem>\d+)"
        )
        custom_match = custom_patt.match(machine_type)
        if custom_match is not None:
            groups = custom_match.groupdict()
            cpus, mem = (groups[k] for k in ["cpus", "mem"])
            machine_info = {
                "guestCpus": int(cpus),
                "memoryMb": int(mem),
            }
        else:
            machines = self.machine_types()
            if machine_type not in machines:
                raise Exception(f"machine type {machine_type} not found")
            per_zone = machines[machine_type]
            assert per_zone
            machine_info = next(iter(per_zone.values())) # pick the first/any zone
        return NSDict(machine_info)

    def template_machine_conf(self, template_link):
        template = self.template_info(template_link)
        if not template.machineType:
            temp_name = trim_self_link(template_link)
            raise Exception(f"instance template {temp_name} has no machine type")
        template.machine_info = self.machine_type(template.machineType)
        machine = template.machine_info

        machine_conf = NSDict()
        machine_conf.boards = 1  # No information, assume 1
        machine_conf.sockets = machine_type_sockets(template)
        # the value below for SocketsPerBoard must be type int
        machine_conf.sockets_per_board = machine_conf.sockets // machine_conf.boards
        machine_conf.threads_per_core = 1
        _div = 2 if getThreadsPerCore(template) == 1 else 1
        machine_conf.cpus = (
            int(machine.guestCpus / _div) if isSmt(template) else machine.guestCpus
        )
        machine_conf.cores_per_socket = int(machine_conf.cpus / machine_conf.sockets)
        # Because the actual memory on the host will be different than
        # what is configured (e.g. kernel will take it). From
        # experiments, about 16 MB per GB are used (plus about 400 MB
        # buffer for the first couple of GB's. Using 30 MB to be safe.
        gb = machine.memoryMb // 1024
        machine_conf.memory = machine.memoryMb - (400 + (30 * gb))
        return machine_conf

    @contextmanager
    def template_cache(self, writeback=False):
        flag = "c" if writeback else "r"
        err = None
        for wait in backoff_delay(0.125, timeout=60, count=20):
            try:
                cache = shelve.open(
                    str(self.template_cache_path), flag=flag, writeback=writeback
                )
                break
            except OSError as e:
                err = e
                log.debug(f"Failed to access template info cache: {e}")
                sleep(wait)
                continue
        else:
            # reached max_count of waits
            raise Exception(f"Failed to access cache file. latest error: {err}")
        try:
            yield cache
        finally:
            cache.close()

    @lru_cache(maxsize=None)
    def template_info(self, template_link):
        template_name = trim_self_link(template_link)
        # split read and write access to minimize write-lock. This might be a
        # bit slower? TODO measure
        if self.template_cache_path.exists():
            with self.template_cache() as cache:
                if template_name in cache:
                    return NSDict(cache[template_name])

        template = ensure_execute(
            self.compute.instanceTemplates().get(
                project=self.project, instanceTemplate=template_name
            )
        ).get("properties")
        template = NSDict(template)
        # name and link are not in properties, so stick them in
        template.name = template_name
        template.link = template_link
        # TODO delete metadata to reduce memory footprint?
        # del template.metadata

        # translate gpus into an easier-to-read format
        machine_info = self.machine_type(template.machineType)
        if machine_info.accelerators:
            template.gpu_type = machine_info.accelerators[0].guestAcceleratorType
            template.gpu_count = machine_info.accelerators[0].guestAcceleratorCount
        elif template.guestAccelerators:
            template.gpu_type = template.guestAccelerators[0].acceleratorType
            template.gpu_count = template.guestAccelerators[0].acceleratorCount
        else:
            template.gpu_type = None
            template.gpu_count = 0

        # keep write access open for minimum time
        with self.template_cache(writeback=True) as cache:
            cache[template_name] = template.to_dict()
        # cache should be owned by slurm
        chown_slurm(self.template_cache_path)

        return template

    def nodeset_map(self, hostnames: list):
        """Convert a list of nodes into a map of nodeset_name to hostnames"""
        nodeset_map = collections.defaultdict(list)
        for node in hostnames:
            nodeset_map[self.node_nodeset_name(node)].append(node)
        return nodeset_map

    @property
    def etc_dir(self) -> Path:
        return Path(self.cfg.output_dir or slurmdirs.etc)

_lkp: Optional[Lookup] = None

def _load_config() -> NSDict:
    return NSDict(yaml.safe_load(CONFIG_FILE.read_text()))

def lookup() -> Lookup:
    global _lkp
    if _lkp is None:
        try:
            cfg =  _load_config()
        except FileNotFoundError:
            log.error(f"config file not found: {CONFIG_FILE}")
            cfg = NSDict() # TODO: fail here, once all code paths are covered (mainly init_logging)
        _lkp = Lookup(cfg)
    return _lkp

def update_config(cfg: NSDict) -> None:
    global _lkp
    _lkp = Lookup(cfg)

def scontrol_reconfigure(lkp: Lookup) -> None:
    log.info("Running scontrol reconfigure")
    run(f"{lkp.scontrol} reconfigure", timeout=30)
