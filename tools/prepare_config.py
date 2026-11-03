"""Prepare a consumer's own ignored configuration. Never print configuration values."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def prepare(source: Path, destination: Path):
    values = json.loads(source.read_text())
    if not isinstance(values, dict):
        raise ValueError('Demo configuration must be a JSON object')
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(values, ensure_ascii=False, indent=2) + '\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'Config/pikd.local.json')
    parser.add_argument('--destination', type=Path, default=ROOT / 'PIKDDemo/DemoConfiguration.json')
    args = parser.parse_args()
    if not args.source.is_file():
        raise SystemExit('Copy Config/pikd.example.json to Config/pikd.local.json and supply your host values.')
    try:
        prepare(args.source, args.destination)
    except (ValueError, OSError):
        raise SystemExit('Unable to prepare demo configuration; no private values were logged.') from None
    print('Demo configuration prepared (values omitted).')
