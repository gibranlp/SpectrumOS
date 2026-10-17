#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
import time

name=Path(sys.argv[0]).name
root=Path(os.environ['SPECTRUM_QUESTLINE_TEST_DIR'])
if name=='questline-adapter':
    print((root/'catalog.json').read_text())
elif name=='questline-action':
    payload=json.loads(sys.argv[1])
    time.sleep(0.12)
    with (root/'actions.jsonl').open('a') as output:output.write(json.dumps(payload)+'\n')
    print(json.dumps({'id':payload.get('id',payload.get('autosave_id','generated'))}))
elif len(sys.argv)>1 and sys.argv[1]=='colors':print('[]')
elif len(sys.argv)>1 and sys.argv[1]=='questline-campaign':print('campaign-a')
else:print('{}')
