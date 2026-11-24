"""Unit tests for the `board.rounds` helpers in record_screen.py."""
import unittest

from record_screen import all_rounds, mode_rounds, set_rounds


def entry(set_id, mode):
    """One `board.rounds` entry: the fields the helpers read, plus an identity field."""
    return {'set': set_id, 'mode': mode,
            'golden': f'tests/goldens/gameplay-{set_id}-{mode}/capture.json',
            'golden_sha256': f'{set_id}-{mode}'}


def board(rounds):
    """The screen's own round (Cinema, Arcade) and its `board.rounds` table."""
    return {'set': 'cinema', 'mode': 'arcade', 'rounds': rounds}


# The eight rounds of today's layout: five other sets' Arcade rounds, then the three other
# modes' rounds on the screen's own set (Cinema), in the old tables' order.
SET_IDS = ('zoo', 'candy_factory', 'luxury_stores', 'magic_library', 'birthday_party')
MODE_IDS = ('kill', 'green_zone', 'pac_man')


def today():
    old_sets = {set_id: entry(set_id, 'arcade') for set_id in SET_IDS}
    old_modes = {mode: entry('cinema', mode) for mode in MODE_IDS}
    rounds = {f'{set_id}/arcade': old_sets[set_id] for set_id in SET_IDS}
    rounds.update({f'cinema/{mode}': old_modes[mode] for mode in MODE_IDS})
    return board(rounds), old_sets, old_modes


class RoundsTest(unittest.TestCase):
    def test_today_matches_old_sets_and_modes_tables(self):
        own, old_sets, old_modes = today()
        self.assertEqual(set_rounds(own), old_sets)
        self.assertEqual(mode_rounds(own), old_modes)
        # The manifests are written in these orders: the group ids, sorted.
        self.assertEqual(list(set_rounds(own)), sorted(SET_IDS))
        self.assertEqual(list(mode_rounds(own)), sorted(MODE_IDS))

    def test_all_rounds_is_the_boards_own_plus_every_entry(self):
        own, _, _ = today()
        rounds = all_rounds(own)
        self.assertIs(rounds[0], own)
        self.assertEqual(len(rounds), 1 + 8)
        self.assertEqual([r['set'] + '/' + r['mode'] for r in rounds[1:]],
                         [set_id + '/arcade' for set_id in SET_IDS]
                         + ['cinema/' + mode for mode in MODE_IDS])

    def test_adding_zoo_kill_keeps_the_set_and_mode_rounds(self):
        own, old_sets, old_modes = today()
        zoo_kill = entry('zoo', 'kill')
        grown = board(dict(own['rounds'], **{'zoo/kill': zoo_kill}))
        self.assertIs(set_rounds(grown)['zoo'], old_sets['zoo'])
        self.assertIs(mode_rounds(grown)['kill'], old_modes['kill'])
        self.assertIn(zoo_kill, all_rounds(grown))
        self.assertEqual(len(all_rounds(grown)), 1 + 9)
        self.assertEqual(set_rounds(grown), old_sets)
        self.assertEqual(mode_rounds(grown), old_modes)

    def test_inserting_birthday_party_kill_keeps_the_mode_rounds_order(self):
        # `birthday_party/kill` sorts first; a manifest written without `sort_keys` may list
        # it before the screen's own modes, but the mode order and picks must not follow it.
        own, _, old_modes = today()
        rounds = {'birthday_party/kill': entry('birthday_party', 'kill')}
        rounds.update(own['rounds'])
        grown = board(rounds)
        self.assertEqual(list(mode_rounds(grown)), sorted(MODE_IDS))
        self.assertEqual(mode_rounds(grown), old_modes)
        self.assertIs(mode_rounds(grown)['kill'], old_modes['kill'])

    def test_a_set_without_an_arcade_round_still_gets_its_first_sorted_round(self):
        pac_man = entry('zoo', 'pac_man')
        kill = entry('zoo', 'kill')
        own = board({'zoo/pac_man': pac_man, 'zoo/kill': kill})
        self.assertEqual(set_rounds(own), {'zoo': kill})
        self.assertEqual(mode_rounds(own), {'kill': kill, 'pac_man': pac_man})
        self.assertNotIn('cinema', set_rounds(own))

    def test_a_mode_falls_back_to_its_first_sorted_round(self):
        zoo_kill = entry('zoo', 'kill')
        candy_kill = entry('candy_factory', 'kill')
        own = board({'zoo/kill': zoo_kill, 'candy_factory/kill': candy_kill})
        self.assertEqual(mode_rounds(own), {'kill': candy_kill})

    def test_empty_rounds_table(self):
        own = board({})
        self.assertEqual(all_rounds(own), [own])
        self.assertEqual(set_rounds(own), {})
        self.assertEqual(mode_rounds(own), {})


if __name__ == '__main__':
    unittest.main()
