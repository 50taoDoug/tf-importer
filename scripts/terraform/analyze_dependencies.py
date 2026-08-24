#!/usr/bin/env python3
"""
Analyze an environment's auto_generated.tf and imports_generated.tf files and
build a graph of actual resource dependencies from literal IDs and ARNs
referenced by one resource inside another resource's body.

Usage: analyze_dependencies.py <auto_generated.tf> <imports_generated.tf> <output.json>

Note: an isolated resource does not necessarily have no real relationships.
The related resource may not have been captured during discovery. For example,
untagged Lambda log groups created automatically by AWS do not appear in the
Resource Groups Tagging API.
"""
import json
import re
import sys
from collections import defaultdict


def extract_resources(tf_path):
    with open(tf_path) as f:
        content = f.read()

    resources = []
    pattern = re.compile(r'resource\s+"([a-zA-Z0-9_]+)"\s+"([a-zA-Z0-9_]+)"\s*\{')

    for m in pattern.finditer(content):
        rtype, rname = m.group(1), m.group(2)
        start = m.end()
        depth = 1
        i = start
        while depth > 0 and i < len(content):
            if content[i] == '{':
                depth += 1
            elif content[i] == '}':
                depth -= 1
            i += 1
        body = content[start:i]
        resources.append({"type": rtype, "name": rname, "address": f"{rtype}.{rname}", "text": body})

    return resources


def extract_identities(imports_path):
    with open(imports_path) as f:
        content = f.read()

    identities = {}
    for block in re.finditer(r'import\s*\{([^}]*)\}', content, re.S):
        body = block.group(1)
        to_m = re.search(r'to\s*=\s*([a-zA-Z0-9_.]+)', body)
        id_m = re.search(r'id\s*=\s*"([^"]+)"', body)
        if to_m and id_m:
            identities[to_m.group(1)] = id_m.group(1)

    return identities


def find_edges(resources, identities):
    edges = []
    for r in resources:
        addr = r['address']
        text = r['text']
        for other_addr, other_id in identities.items():
            if other_addr == addr:
                continue
            if len(other_id) < 6:
                continue
            if f'"{other_id}"' in text:
                edges.append({
                    "source": addr,
                    "target": other_addr,
                    "identity": other_id,
                    "match": "exact_quoted_identity",
                })
    return edges


class UnionFind:
    def __init__(self, nodes):
        self.parent = {n: n for n in nodes}

    def find(self, x):
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[ra] = rb


def main():
    if len(sys.argv) != 4:
        print("Usage: analyze_dependencies.py <auto_generated.tf> <imports_generated.tf> <output.json>")
        sys.exit(1)

    tf_path, imports_path, output_path = sys.argv[1], sys.argv[2], sys.argv[3]

    resources = extract_resources(tf_path)
    identities = extract_identities(imports_path)

    all_addrs = [r['address'] for r in resources]
    type_by_addr = {r['address']: r['type'] for r in resources}
    uf = UnionFind(all_addrs)

    edges = find_edges(resources, identities)
    for edge in edges:
        a = edge["source"]
        b = edge["target"]
        if a in uf.parent and b in uf.parent:
            uf.union(a, b)

    clusters = defaultdict(list)
    for addr in all_addrs:
        clusters[uf.find(addr)].append(addr)

    grouped = sorted(
        [v for v in clusters.values() if len(v) > 1],
        key=lambda x: -len(x)
    )
    isolated = sorted([v[0] for v in clusters.values() if len(v) == 1])

    result = {
        "summary": {
            "total_resources": len(resources),
            "total_identities": len(identities),
            "total_edges": len(edges),
            "total_clusters": len(grouped),
            "total_isolated": len(isolated),
        },
        "clusters": [
            {
                "id": i,
                "size": len(members),
                "members": sorted(members),
                "types_present": sorted(set(type_by_addr[m] for m in members)),
            }
            for i, members in enumerate(grouped, 1)
        ],
        "isolated": [
            {"address": addr, "type": type_by_addr[addr]}
            for addr in isolated
        ],
        "edges": sorted(
            edges,
            key=lambda edge: (
                edge["source"],
                edge["target"],
                edge["identity"],
            ),
        ),
    }

    with open(output_path, 'w') as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    print(f"Clusters: {len(grouped)} | Isolated: {len(isolated)} | References: {len(edges)}")
    print(f"Report saved to: {output_path}")


if __name__ == "__main__":
    main()
