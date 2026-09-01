import 'package:flutter_test/flutter_test.dart';
import 'package:patients/models/appointment_models.dart';

void main() {
  test('tryFromVisit rebuilds a booking from a live queue row', () {
    final details = AppointmentDetails.tryFromVisit(
      {
        'queueId': '42',
        'tokenNumber': 'A-12',
        'hospitalId': 7,
        'hospitalName': 'DHQ Lahore',
        'hospitalDepartmentId': 3,
        'departmentName': 'Medicine',
        'appointmentDate': '2026-08-19T09:30:00',
      },
      patientName: 'Test Patient',
      patientMRN: '12345',
    );

    expect(details, isNotNull);
    expect(details!.queueResponse.queueId, 42);
    expect(details.queueResponse.tokenNumber, 'A-12');
    expect(details.hospital.name, 'DHQ Lahore');
    expect(details.department.name, 'Medicine');
    expect(details.patientName, 'Test Patient');
  });

  test('tryFromVisit returns null without a queue id', () {
    expect(
      AppointmentDetails.tryFromVisit(
        {'tokenNumber': 'A-12', 'hospitalName': 'DHQ'},
        patientName: 'Test Patient',
        patientMRN: '12345',
      ),
      isNull,
    );
  });
}
