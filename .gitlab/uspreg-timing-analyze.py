"""Extract connect, received handshake and sent REGISTER on the same socket."""
import csv
import json
from pathlib import Path
import statistics
import sys


def varint(data, pos):
    value = shift = 0
    while pos < len(data) and shift < 70:
        byte = data[pos]
        pos += 1
        value |= (byte & 127) << shift
        if not byte & 128:
            return value, pos
        shift += 7
    raise ValueError('invalid protobuf varint')


def fields(data):
    pos, result = 0, {}
    while pos < len(data):
        tag, pos = varint(data, pos)
        kind = tag & 7
        if kind == 0:
            value, pos = varint(data, pos)
        elif kind in (1, 2, 5):
            if kind == 2:
                size, pos = varint(data, pos)
            else:
                size = 8 if kind == 1 else 4
            if pos + size > len(data):
                raise ValueError('truncated protobuf field')
            value = data[pos:pos + size]
            pos += size
        else:
            raise ValueError('unsupported protobuf field')
        result[tag >> 3] = value
    return result


def frame_kind(frame, direction):
    pos = 0
    while pos < len(frame):
        if pos + 5 > len(frame):
            raise ValueError('truncated TLV header')
        kind, size = frame[pos], int.from_bytes(frame[pos + 1:pos + 5], 'big')
        pos += 5
        value = frame[pos:pos + size]
        if len(value) != size:
            raise ValueError('truncated TLV value')
        pos += size
        if kind == 1 and direction == 'read':
            return 'handshake_received'
        if kind == 3 and direction == 'write':
            record = fields(value)
            if 7 in record:
                message = fields(fields(record[7])[2])
                if fields(message[1]).get(2) == 19:
                    return 'REGISTER_sent'
    return None


def extract(path, broker):
    events, buffers, finished = [], {}, set()
    for line, text in enumerate(path.read_text().splitlines(), 1):
        row = dict(item.split('=', 1) for item in text.split())
        stamp = int(row['sec']) * 1_000_000_000 + int(row['ns'])
        socket = (int(row['pid']), int(row['inode']))
        if int(row['peer']) != broker:
            continue
        common = {'pid': socket[0], 'inode': socket[1], 'monotonic_ns': stamp,
                  'source_line': line}
        if row['op'] == 'connect':
            events.append(common | {'event': 'connect'})
            continue
        if int(row['result']) <= 0 or row['op'] == 'close':
            continue
        direction = 'read' if row['op'].startswith('r') else 'write'
        key = socket + (direction,)
        if key in finished:
            continue
        data = bytes.fromhex(row['data'])
        if len(data) != int(row['result']):
            # No event is inferred across a capture gap. Other sockets remain usable.
            finished.add(key)
            events.append(common | {'event': 'capture_gap_' + direction})
            continue
        buffer = buffers.get(key, b'') + data
        while len(buffer) >= 8:
            if buffer[:4] != b'_USP':
                raise ValueError('IMTP stream lost framing')
            size = 8 + int.from_bytes(buffer[4:8], 'big')
            if size > 16 * 1024 * 1024:
                raise ValueError('implausible IMTP frame size')
            if len(buffer) < size:
                break
            kind = frame_kind(buffer[8:size], direction)
            buffer = buffer[size:]
            if kind:
                events.append(common | {'event': kind})
                finished.add(key)
                buffer = b''
                break
        buffers[key] = buffer
    candidates = []
    for registration in (event for event in events if event['event'] == 'REGISTER_sent'):
        related = [event for event in events if
                   (event['pid'], event['inode']) == (registration['pid'], registration['inode'])]
        connects = [event for event in related if event['event'] == 'connect']
        handshakes = [event for event in related if event['event'] == 'handshake_received']
        if connects and handshakes:
            connect, handshake = connects[-1], handshakes[0]
            if connect['monotonic_ns'] <= handshake['monotonic_ns'] <= registration['monotonic_ns']:
                candidates.append({'pid': registration['pid'], 'inode': registration['inode'],
                                   'delay_seconds': (handshake['monotonic_ns'] - connect['monotonic_ns']) / 1e9,
                                   'connect_ns': connect['monotonic_ns'],
                                   'handshake_ns': handshake['monotonic_ns'],
                                   'register_ns': registration['monotonic_ns']})
    if len(candidates) != 1:
        raise ValueError(f'expected one socket with connect/handshake/REGISTER; found {len(candidates)}')
    return candidates[0], events


def analyze(root):
    rows, all_events, retry_lines = [], [], []
    directories = sorted(root.glob('run-*'))
    assert len(directories) == 10, 'expected exactly ten timing observations'
    for directory in directories:
        run = int(directory.name.split('-')[1])
        row = {'run': run}
        try:
            sample, events = extract(directory / 'service-socket-io.log',
                                     int((directory / 'broker.pid').read_text()))
            row.update(sample, status='valid')
            all_events.extend({'run': run} | event for event in events)
        except (ValueError, KeyError, OSError) as error:
            row.update(status='invalid', reason=str(error))
        rows.append(row)
        marker = f'begin run={run}'
        active = False
        for number, line in enumerate((directory / 'logread-stream.txt').read_text().splitlines(), 1):
            if 'USP-TIMING' in line and marker in line:
                active = True
            if active and 'USP registration' in line:
                retry_lines.append(f'{directory.name}/logread-stream.txt:{number}: {line}')
    values = [row['delay_seconds'] for row in rows if row['status'] == 'valid']
    summary = {'clock': 'CLOCK_MONOTONIC', 'timestamp': 'after successful socket syscall',
               'valid': len(values), 'invalid': len(rows) - len(values),
               'min_seconds': min(values) if values else None,
               'median_seconds': statistics.median(values) if values else None,
               'max_seconds': max(values) if values else None,
               'above_2_seconds': sum(value > 2 for value in values), 'runs': rows}
    (root / 'timing.json').write_text(json.dumps(summary, indent=2) + '\n')
    with (root / 'events.tsv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=['run', 'event', 'monotonic_ns', 'pid', 'inode', 'source_line'], delimiter='\t')
        writer.writeheader()
        writer.writerows(all_events)
    (root / 'retry-lines.txt').write_text('\n'.join(retry_lines) + ('\n' if retry_lines else ''))
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    analyze(Path(sys.argv[1]))
