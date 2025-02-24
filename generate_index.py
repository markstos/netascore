import argparse
import sys
import yaml
import re
from typing import List

import toolbox.helper as h
from core.attributes_step import create_attributes_step
from core.db_step import DbStep
from core.export_step import create_exporter
from core.import_step import create_importer
from core.index_step import generate_index, load_weights
from core.network_step import create_network_step
from core.optional_step import run_optional_importers
from settings import DbSettings, GlobalSettings

parser = argparse.ArgumentParser(description='TODO: add description')
parser.add_argument('settings_file', type=argparse.FileType('r'),
                    help='TODO: write detailed description here')
parser.add_argument('--skip', nargs='+', choices=['import', 'optional', 'network', 'attributes', 'index', 'export'],
                    help='skip one or more of these steps - e.g. "--skip import optional"')
parser.add_argument('--loglevel', nargs=1, choices=["1", "2", "3", "4"],
                    help="Sets the level of debug outputs on the console: 1=MajorInfo, 2=Info, 3=Detailed, 4=Debug")

args = parser.parse_args()
settings_stream = args.settings_file
skip_steps = args.skip or []
base_path = settings_stream.name.rsplit('/', 1)[0]
if args.loglevel:
    h.verbose_level = int(args.loglevel[0])
    h.majorInfo(f"using log level {h.verbose_level}")

h.info(f'loading {settings_stream.name}')
h.info(f'skip steps: {str(skip_steps)}')

def require_allowed_value(setting_value: str, setting_name: str, allowed: List[str]):
    for value in allowed:
        if value == setting_value:
            return

    h.majorInfo(setting_name + ': ' + setting_value + ' is not one of the allowed values: ' + ' '.join(allowed))
    sys.exit(1)


def require_on_existing_setting(settings: dict):
    if 'on_existing' not in settings:
        h.info('defaulting \'on_existing\' to \'skip\'')
        settings['on_existing'] = 'skip'
    require_allowed_value(settings['on_existing'], 'on_existing', ['skip', 'delete', 'abort'])


with settings_stream:
    settings: dict = yaml.safe_load(settings_stream)

    # process global settings if given
    if h.has_keys(settings, ['global']):
        global_settings: dict = settings['global']
        if h.has_keys(global_settings, ['target_srid']):
            GlobalSettings.custom_srid = re.sub("[^0-9]", "", global_settings['target_srid'])
            h.info(f"Set the target SRID to {GlobalSettings.get_target_srid()}")
        if h.has_keys(global_settings, ['case_id']):
            GlobalSettings.case_id = re.sub("[^a-zA-Z0-9_]", "", global_settings['case_id'])
    
    db_settings: DbSettings = DbSettings.from_dict(settings.get('database'))

    # check if all required sections are present first before taking any actions
    if 'import' not in skip_steps:
        h.require_keys(settings, ['import'], 'error: section missing:')
    if 'export' not in skip_steps:
        h.require_keys(settings, ['export'], 'error: section missing:')
    if 'index' not in skip_steps:
        h.require_keys(settings, ['weights'], 'error: section missing:')

    # execute processing steps
    if 'import' not in skip_steps:
        h.majorInfo(' === importing ===')
        import_settings: dict = settings['import']
        h.require_keys(import_settings, ['type'], 'error: import section is missing:')
        require_on_existing_setting(import_settings)
        importer: DbStep = create_importer(db_settings, import_settings['type'])
        importer.run_step(import_settings)
    else:
        h.majorInfo(' === skipping import ===')

    if 'optional' not in skip_steps and 'optional' in settings:
        h.majorInfo(' === running optional importers ===')
        run_optional_importers(db_settings, settings.get('optional'))

    if 'network' not in skip_steps and 'import' in settings:
        # TODO: specify settings key that is needed by the network step
        h.majorInfo(' === running network step ===')
        # TODO: add error handling for import_settings
        # TODO: code repetition
        import_settings: dict = settings['import']
        h.require_keys(import_settings, ['type'], 'error: import section is missing:')
        require_on_existing_setting(import_settings)
        network_step: DbStep = create_network_step(db_settings, import_settings['type'])
        network_step.run_step(import_settings)

    if 'attributes' not in skip_steps and 'import' in settings:
        # TODO: specify settings key that is needed by the attributes step
        h.majorInfo(' === running attributes step ===')
        # TODO: add error handling for import_settings
        # TODO: code repetition
        import_settings: dict = settings['import']
        h.require_keys(import_settings, ['type'], 'error: import section is missing:')
        require_on_existing_setting(import_settings)
        attributes_step: DbStep = create_attributes_step(db_settings, import_settings['type'])
        attributes_step.run_step(import_settings)

    if 'index' not in skip_steps:
        h.majorInfo(' === generating index ===')
        weight_definitions: dict = settings['weights']
        weights = load_weights(base_path, weight_definitions)
        generate_index(db_settings, weights)

    if 'export' not in skip_steps:
        h.majorInfo(' === exporting ===')
        export_settings: dict = settings['export']
        h.require_keys(export_settings, ['type'], 'error: export section is missing:')
        exporter: DbStep = create_exporter(db_settings, export_settings['type'])
        exporter.run_step(export_settings)
    else:
        h.majorInfo('skipping export (as listed in skip_steps)')
