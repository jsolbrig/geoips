# # # Distribution Statement A. Approved for public release. Distribution unlimited.
# # #
# # # Author:
# # # Naval Research Laboratory, Marine Meteorology Division
# # #
# # # This program is free software: you can redistribute it and/or modify it under
# # # the terms of the NRLMMD License included with this program. This program is
# # # distributed WITHOUT ANY WARRANTY; without even the implied warranty of
# # # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the included license
# # # for more details. If you did not receive the license, for more information see:
# # # https://github.com/U-S-NRL-Marine-Meteorology-Division/

"""Reader interface will be deprecated v2.0.

Wrapper functions for geoips reader interfacing.

This functionality will be replaced with a class-based implementation v2.0,
and deprecated at that time.
"""
import collections
from importlib import import_module
import logging

from geoips.geoips_utils import find_entry_point, list_entry_points

LOG = logging.getLogger(__name__)


### Reader functions ###
def is_valid_reader(reader_name):
    """Interface will be deprecated v2.0.

    Check that the requested function has the correct call signature.
    Return values should be as specified below, but are not programmatically verified.

    Parameters
    ----------
    reader_name :str
        Desired reader function
        (ie, 'amsr2_ncdf', 'ahi_hsd', etc)

    Returns
    -------
    bool
        * True if 'reader_name' has the appropriate call signature
        * False if reader function:

            * does not contain all required arguments
            * does not contain all required keyword arguments

    Notes
    -----
    Reader functions currently defined in
        <geoips_package>.readers.<reader_name>.<reader_name>
    and requested via commandline with:
        --reader_name <reader_name>

    Reader types currently one of:

    * 'standard'

        * call signature <reader_name>(fnames, metadata_only=False, chans=None,
          area_def=None, self_register=False)
        * return value: list of xarray objects (one xarray object for each
          shape/resolution of data)
    """
    required_args = {"standard": ["fnames"]}
    required_kwargs = {
        "standard": ["metadata_only", "chans", "area_def", "self_register"]
    }

    try:
        reader_type = get_reader_type(reader_name)
    except ImportError as resp:
        LOG.warning(
            f'Module {reader_name} in readers package not a valid reader: If this is intended to be a valid reader, ensure "reader_type" is defined: Exception: "{resp}"'
        )
        return False
    try:
        reader_func = get_reader(reader_name)
    except ImportError as resp:
        raise ImportError(
            f'INVALID READER {reader_name}: Must specify function "{reader_name}" within module "{reader_name}": Exception: "{resp}"'
        )

    num_args = len(required_args[reader_type])
    num_kwargs = len(required_kwargs[reader_type])

    # If this is __init__ (no __code__ attr), skip it
    if not hasattr(reader_func, "__code__"):
        return False
    reader_vars = reader_func.__code__.co_varnames
    reader_args = reader_vars[0:num_args]
    reader_kwargs = reader_vars[num_args : num_args + num_kwargs]

    # Check for required call signature arguments
    if not set(required_args[reader_type]).issubset(set(reader_args)):
        LOG.error(
            "INVALID READER '%s': '%s' reader type must have required arguments: '%s'",
            reader_name,
            reader_type,
            required_args[reader_type],
        )
        return False

    # Check for optional call signature keyword arguments
    if not set(required_kwargs[reader_type]).issubset(set(reader_kwargs)):
        LOG.error(
            "INVALID READER '%s': '%s' reader type must have optional kwargs: '%s'",
            reader_name,
            reader_type,
            required_kwargs[reader_type],
        )
        return False

    return True


def get_reader(reader_name):
    """Interface will be deprecated v2.0.

    Retrieve the requested reader function

    See: geoips.stable.reader.is_valid_reader for full list of supported reader
    function call signatures and return values

    Parameters
    ----------
    reader_name : str
        Desired reader function
        (ie, 'amsr2_ncdf', 'ahi_hsd', etc)

    Returns
    -------
    function
        Reader function, currently specified in
        <geoips_package>.readers.<reader_name>.<reader_name>
    """
    return find_entry_point("readers", reader_name)


def get_reader_type(reader_name):
    """Interface will be deprecated v2.0.

    Retrieve type of the requested reader function.
    Type specifies the required call signature and return values

    See: geoips.stable.reader.is_valid_reader for full list of supported
    reader function call signatures and return values

    Parameters
    ----------
    reader_name : str
        Desired reader function
        (ie, 'amsr2_ncdf', 'ahi_hsd', etc)

    Returns
    -------
    str
        Reader function type, currently found in
        <geoips_package>.readers.<reader_name>.reader_type
        Type defaults to 'standard' if not specified.
    """
    reader_func = find_entry_point("readers", reader_name)
    return getattr(import_module(reader_func.__module__), "reader_type")


def list_readers_by_type():
    """Interface will be deprecated v2.0.

    List all available reader functions within the current GeoIPS
    instantiation, sorted by reader_type

    Reader function "type" determines exact required call signatures
    and return values

    Returns
    -------
    dict
        Dictionary with all reader function types as keys, and associated
        reader function names (str) as values.

    See Also
    --------
    * See geoips_utils.is_valid_reader? for a list of available reader
      types and associated call signatures / return values.
    * See geoips_utils.get_reader(reader_name) to retrieve the requested reader
    """
    all_readers = collections.defaultdict(list)
    for reader in list_entry_points("readers"):
        reader_type = get_reader_type(reader)
        if reader not in all_readers[reader_type]:
            all_readers[reader_type].append(reader)
    return all_readers


def test_reader_interface():
    """Interface will be deprecated v2.0.

    Finds and opens every reader func available within the current geoips
    instantiation

    Returns
    -------
    dict
        dict of all successful output from all reader interface calls.

    See Also
    --------
    * See geoips_utils.is_valid_reader? for a list of available reader types
      and associated call signatures / return values.
    * See geoips_utils.get_reader(reader_name) to retrieve the requested reader
    """
    curr_names = list_readers_by_type()
    out_dict = {
        "by_type": curr_names,
        "validity_check": {},
        "func_type": {},
        "func": {},
    }
    for curr_type in curr_names:
        for curr_name in curr_names[curr_type]:
            out_dict["validity_check"][curr_name] = is_valid_reader(curr_name)
            out_dict["func"][curr_name] = get_reader(curr_name)
            out_dict["func_type"][curr_name] = get_reader_type(curr_name)
    return out_dict
