# SPDX-License-Identifier: GPL-2.0-only
from __future__ import annotations

import zlib


class DVZipReader:
    def __init__(self, source, block=1 << 16):
        self.source = source
        self.block = block
        self.pending = bytearray()
        self.finished = False
        self.bytes_read = 0

    def read(self, size=8192):
        if size < 0:
            raise ValueError('DVZip streaming requires a bounded read size')
        if size == 0:
            return b''
        while len(self.pending) < size and not self.finished:
            raw = self.source.read(self.block)
            if not raw:
                self.finished = True
                break
            compressed = zlib.compress(raw, 6)
            if len(compressed) < len(raw):
                self.pending += len(compressed).to_bytes(4, 'big') + compressed
            else:
                self.pending += (0x80000000 | len(raw)).to_bytes(4, 'big') + raw
        count = min(size, len(self.pending))
        result = bytes(self.pending[:count])
        del self.pending[:count]
        self.bytes_read += count
        return result
