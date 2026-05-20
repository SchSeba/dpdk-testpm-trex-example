#!/usr/bin/env python3
"""Patch VPP's HTTP plugin sources to honor the HTTP/2 build toggle."""

from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()
pattern = re.compile(
    r'option\(VPP_ENABLE_HTTP_2 "Build http plugin with HTTP/2 enabled" OFF\)\n'
    r'if\(VPP_ENABLE_HTTP_2\)\n'
    r'\s+add_compile_definitions\(HTTP_2_ENABLE=1\)\n'
    r'endif\(\)\n\n'
    r'add_vpp_plugin\(http\n'
    r'\s+SOURCES\n'
    r'\s+http2/hpack\.c\n'
    r'\s+http2/http2\.c\n'
    r'\s+http2/frame\.c\n'
    r'\s+http\.c\n'
    r'\s+http_buffer\.c\n'
    r'\s+http_timer\.c\n'
    r'\s+http1\.c\n'
    r'\)\n',
    re.MULTILINE,
)
replacement = """option(VPP_ENABLE_HTTP_2 "Build http plugin with HTTP/2 enabled" OFF)

set(HTTP_PLUGIN_SOURCES
  http.c
  http_buffer.c
  http_timer.c
  http1.c
)

if(VPP_ENABLE_HTTP_2)
    add_compile_definitions(HTTP_2_ENABLE=1)
    list(APPEND HTTP_PLUGIN_SOURCES
      http2/hpack.c
      http2/http2.c
      http2/frame.c
    )
endif()

add_vpp_plugin(http
  SOURCES
  ${HTTP_PLUGIN_SOURCES}
)
"""
patched, count = pattern.subn(replacement, text, count=1)

if count != 1:
    raise SystemExit(f"expected http plugin block not found in {path}")

path.write_text(patched)
