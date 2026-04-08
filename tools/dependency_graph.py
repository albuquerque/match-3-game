#!/usr/bin/env python3
"""
Generate a Mermaid dependency graph and unused-files list for the workspace.
Writes:
 - tools/dependency_graph.mmd  (Mermaid graph)
 - tools/unused_files.txt     (candidate files with zero incoming refs)

Usage: python3 tools/dependency_graph.py
"""
import os
import re
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(__file__)) if __file__ else os.getcwd()
ROOT = os.path.abspath(ROOT)
IGNORE_DIRS = {'.git', 'android', 'builds', 'tools', '.godot', 'tests', 'build'}

# Candidate file extensions to consider as nodes
NODE_EXTS = {'.gd', '.tscn'}
# Files to scan for references (content sources)
SCAN_EXTS = {'.gd', '.tscn', '.tres', '.json', '.cfg', '.godot', '.md'}


def collect_candidates(root):
    candidates = []
    for dirpath, dirs, files in os.walk(root):
        # prune
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        for f in files:
            if os.path.splitext(f)[1] in NODE_EXTS:
                full = os.path.join(dirpath, f)
                rel = os.path.relpath(full, root).replace('\\\\', '/')
                candidates.append(rel)
    return sorted(candidates)


def collect_search_files(root):
    paths = []
    for dirpath, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        for f in files:
            if os.path.splitext(f)[1] in SCAN_EXTS:
                paths.append(os.path.join(dirpath, f))
    return paths


def read_contents(paths):
    contents = {}
    for p in paths:
        try:
            with open(p, 'r', encoding='utf-8', errors='replace') as fh:
                contents[p] = fh.read()
        except Exception:
            contents[p] = ''
    return contents


def build_edges(candidates, contents, root):
    edges = defaultdict(set)   # src -> set(target)
    incoming = {c: set() for c in candidates}
    # Precompute basenames -> candidates list for quick match
    basename_map = defaultdict(list)
    for c in candidates:
        basename_map[os.path.basename(c)].append(c)

    for src_path, text in contents.items():
        src_rel = os.path.relpath(src_path, root).replace('\\\\', '/')
        # Fast check: only try matching if text contains 'res://' or any candidate basename
        if 'res://' not in text and not any(bn in text for bn in basename_map.keys()):
            continue
        for bn, cand_list in basename_map.items():
            if bn in text:
                for cand in cand_list:
                    # match full res:// path also
                    res_path = 'res://' + cand
                    if res_path in text or bn in text:
                        edges[src_rel].add(cand)
                        incoming[cand].add(src_rel)
    return edges, incoming


def load_project_main_scene(root):
    proj = os.path.join(root, 'project.godot')
    if not os.path.exists(proj):
        return None
    try:
        txt = open(proj, 'r', encoding='utf-8', errors='replace').read()
    except Exception:
        return None
    m = re.search(r'run/main_scene\s*=\s*"([^"]+)"', txt)
    return m.group(1) if m else None


def write_mermaid(edges, root, outpath):
    def node_id(name):
        # create safe id for mermaid
        nid = name.replace('/', '_').replace('.', '_').replace('-', '_')
        # ensure it starts with letter
        if not nid[0].isalpha():
            nid = 'n_' + nid
        return nid

    with open(outpath, 'w', encoding='utf-8') as fh:
        fh.write('```mermaid\n')
        fh.write('graph TD\n')
        # write nodes and edges
        for src, targets in sorted(edges.items()):
            for t in sorted(targets):
                fh.write(f'  {node_id(src)}["{src}"] --> {node_id(t)}["{t}"]\n')
        fh.write('```\n')


def write_unused(unused, outpath):
    with open(outpath, 'w', encoding='utf-8') as fh:
        for u in sorted(unused):
            fh.write(u + '\n')


if __name__ == '__main__':
    print('Scanning workspace for .gd/.tscn nodes...')
    candidates = collect_candidates(ROOT)
    print(f'  candidates found: {len(candidates)}')
    search_files = collect_search_files(ROOT)
    print(f'  files to scan: {len(search_files)}')
    contents = read_contents(search_files)
    edges, incoming = build_edges(candidates, contents, ROOT)
    main_scene = load_project_main_scene(ROOT)
    # compute unused: no incoming references (except self) and not main scene
    unused = []
    for c in candidates:
        inc = incoming.get(c, set())
        inc_nonself = set([i for i in inc if i != c])
        if len(inc_nonself) == 0:
            if main_scene and c == main_scene:
                continue
            unused.append(c)
    tools_dir = os.path.join(ROOT, 'tools')
    os.makedirs(tools_dir, exist_ok=True)
    md_out = os.path.join(tools_dir, 'dependency_graph.mmd')
    unused_out = os.path.join(tools_dir, 'unused_files.txt')
    write_mermaid(edges, ROOT, md_out)
    write_unused(unused, unused_out)
    print('Wrote:', md_out)
    print('Wrote:', unused_out)
    print('\nTop 40 unused candidates:')
    for u in sorted(unused)[:40]:
        print('  ' + u)
