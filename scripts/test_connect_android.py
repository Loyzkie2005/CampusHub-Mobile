"""Exercise forwarding selection without connecting to or modifying a phone."""
import contextlib
import io
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
        self.assertEqual(len(calls), 1)

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
