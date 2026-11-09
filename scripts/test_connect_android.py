"""Exercise forwarding selection without connecting to or modifying a phone."""
import contextlib
import io
import subprocess
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import connect_android


class AndroidForwardingSelectionTests(unittest.TestCase):
    wireless = "adb-example-phone (2)._adb-tls-connect._tcp"

    def run_helper(self, output, *arguments):
        with patch.object(connect_android, 'find_adb', return_value='adb.exe'), \
             patch.object(connect_android, 'adb_command', return_value=output) as command, \
             patch.object(sys, 'argv', ['connect_android.py', *arguments]), \
             contextlib.redirect_stdout(io.StringIO()):
            result = connect_android.main()
        return result, command.call_args_list

    def test_wireless_name_with_spaces_is_forwarded_intact(self):
        result, calls = self.run_helper('List of devices attached\n' + self.wireless + '\tdevice\n')
        self.assertEqual(result, 0)
        self.assertEqual([call.args for call in calls], [
            ('adb.exe', 'devices'),
            ('adb.exe', '-s', self.wireless, 'reverse', 'tcp:8000', 'tcp:8000'),
            ('adb.exe', '-s', self.wireless, 'reverse', 'tcp:8001', 'tcp:8001'),
        ])

    def test_usb_phone_is_selected_among_nonready_devices_and_emulator(self):
        result, calls = self.run_helper('List of devices attached\nusb-phone\tdevice\n'
            'not-ready\toffline\nnot-allowed\tunauthorized\nemulator-5554\tdevice\n')
        self.assertEqual(result, 0)
        self.assertEqual(calls[1].args[2], 'usb-phone')

    def test_multiple_phones_are_not_selected_automatically(self):
        result, calls = self.run_helper('first\tdevice\nsecond\tdevice\n')
        self.assertEqual(result, 0)
        self.assertFalse(any('reverse' in call.args for call in calls))

    def test_same_phone_ip_and_discovery_alias_resolve_to_ip(self):
        with patch.object(connect_android, 'adb_command', side_effect=['same-hardware\n', 'same-hardware\n']) as command:
            selected = connect_android.resolve_single_phone('adb.exe', [self.wireless, '192.0.2.1:12345'])
        self.assertEqual(selected, '192.0.2.1:12345')
        self.assertEqual(command.call_args_list[0].args, (
            'adb.exe', '-s', self.wireless, 'shell', '-n', 'getprop', 'ro.serialno'))

    def test_distinct_hardware_is_not_grouped_even_if_both_connected(self):
        with patch.object(connect_android, 'adb_command', side_effect=['hardware-one\n', 'hardware-two\n']):
            self.assertIsNone(connect_android.resolve_single_phone('adb.exe', ['first', 'second']))

    def test_unknown_hardware_cannot_be_assumed_to_be_an_alias(self):
        with patch.object(connect_android, 'adb_command', return_value='unknown\n'):
            self.assertIsNone(connect_android.resolve_single_phone('adb.exe', ['first', 'second']))

    def test_unresponsive_alias_is_not_assumed_to_be_the_same_phone(self):
        with patch.object(connect_android, 'adb_command', side_effect=subprocess.TimeoutExpired('adb', 12)):
            self.assertIsNone(connect_android.resolve_single_phone('adb.exe', ['first', 'second']))

    def test_confirmed_duplicate_transports_are_forwarded_by_default(self):
        output = '192.0.2.1:12345\tdevice\n' + self.wireless + '\tdevice\n'
        with patch.object(connect_android, 'find_adb', return_value='adb.exe'), \
             patch.object(connect_android, 'adb_command', side_effect=[output, 'one-phone\n', 'one-phone\n', '', '']) as command, \
             patch.object(sys, 'argv', ['connect_android.py']), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(connect_android.main(), 0)
        reverses = [call.args for call in command.call_args_list if 'reverse' in call.args]
        self.assertEqual(reverses, [
            ('adb.exe', '-s', '192.0.2.1:12345', 'reverse', 'tcp:8000', 'tcp:8000'),
            ('adb.exe', '-s', '192.0.2.1:12345', 'reverse', 'tcp:8001', 'tcp:8001'),
        ])

    def test_explicit_wireless_selection_preserves_spaces(self):
        result, calls = self.run_helper('first\tdevice\n' + self.wireless + '\tdevice\n',
                                        '--device', self.wireless)
        self.assertEqual(result, 0)
        self.assertEqual(calls[1].args[2], self.wireless)

    def test_unauthorized_explicit_device_is_rejected_without_forwarding(self):
        result, calls = self.run_helper('blocked\tunauthorized\n', '--device', 'blocked')
        self.assertEqual(result, 1)
        self.assertEqual(len(calls), 1)


if __name__ == '__main__':
    unittest.main()
