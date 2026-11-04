"""Read a recorded screen timeline (record_screen.py timeline) and answer layout questions.

A track is a list of changes `[index, state]` where index counts frames since the screen
opened and state is `[a, b, c, d, tx, ty, visible, frame, character, alpha]`, or null while the node is
absent. Indices run from 0 to capture_index + period.
"""
import bisect
import json
from pathlib import Path


def _inverse(m):
    a, b, c, d, tx, ty = m
    det = a * d - b * c
    if abs(det) < 1e-12:
        return None
    ia, ib, ic, id_ = d / det, -b / det, -c / det, a / det
    return [ia, ib, ic, id_, -(ia * tx + ic * ty), -(ib * tx + id_ * ty)]


def _compose(m, n):
    """m ∘ n (apply n, then m), Flash matrix order [a, b, c, d, tx, ty]."""
    a, b, c, d, tx, ty = m
    e, f, g, h, ux, uy = n
    return [a * e + c * f, b * e + d * f, a * g + c * h, b * g + d * h, a * ux + c * uy + tx, b * ux + d * uy + ty]


class Timeline:
    def __init__(self, data):
        self.data = data
        self.tracks = data['tracks']
        self.frames = data['capture_index'] + data['period'] + 1
        self._index = {p: [e[0] for e in t] for p, t in self.tracks.items()}

    @classmethod
    def load(cls, path):
        path = Path(path)
        return cls(json.loads(path.read_text(encoding='utf-8'))) if path.is_file() else None

    def state(self, path, i):
        track = self.tracks.get(path)
        if not track:
            return None
        k = bisect.bisect_right(self._index[path], i) - 1
        return track[k][1] if k >= 0 else None

    def descendants(self, path):
        prefix = path + '/'
        return [p for p in self.tracks if p.startswith(prefix)]

    def children(self, path):
        prefix = path + '/'
        return [p for p in self.tracks if p.startswith(prefix) and '/' not in p[len(prefix):]]

    def changes(self, path):
        return len(self.tracks.get(path, [])) > 1

    def first_visible(self, path):
        for index, state in self.tracks.get(path, []):
            if state is not None and state[6]:
                return index
        return None

    def _relative(self, parent, child, i):
        p, c = self.state(parent, i), self.state(child, i)
        if c is None or p is None:
            return None
        inverse = _inverse(p[:6])
        rel = _compose(inverse, c[:6]) if inverse else c[:6]
        # A descendant's own alpha is played back as a transform-like change, so it is not
        # a change of look (index 9 is alpha; older timelines have none).
        return [round(v, 3) for v in rel] + list(c[6:9])

    def look_changes(self, path):
        """Frame indices where anything inside `path` changes relative to `path` itself
        (moves, shows, hides, appears, changes clip frame). The node's own motion is not a
        change of look: it is played back as a transform."""
        inside = self.descendants(path)
        points = set()
        own = self.tracks.get(path, [])
        for k in range(1, len(own)):
            prev, cur = own[k - 1][1], own[k][1]
            if prev is None or cur is None or prev[7:9] != cur[7:9]:
                points.add(own[k][0])
        candidates = set()
        for d in inside:
            for index, _ in self.tracks[d][1:]:
                candidates.add(index)
        for index, _ in own[1:]:
            candidates.add(index)
        for i in sorted(candidates):
            if i == 0:
                continue
            for d in inside:
                if self._relative(path, d, i) != self._relative(path, d, i - 1):
                    points.add(i)
                    break
        return sorted(points)

    def children_stable(self, path):
        for child in self.children(path):
            if any(state is None for _, state in self.tracks[child]):
                return False
            if self.tracks[child][0][0] != 0:
                return False
        return True
