import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  availabilityCoversBooking,
  blockConflictsWithBooking,
  dateRangesOverlap,
  isValidHHMM,
  timesOverlap,
  weekdayOverlap,
} from './booking-rules';

function commission(amount: number, rate = 0.15) {
  return Math.round(amount * rate * 100) / 100;
}

describe('booking-rules', () => {
  it('detects overlapping weekday windows', () => {
    assert.equal(weekdayOverlap([1, 2, 3, 4, 5], [5, 6]), true);
    assert.equal(weekdayOverlap([1, 2], [3, 4]), false);
  });

  it('detects time overlap', () => {
    assert.equal(timesOverlap('09:00', '18:00', '17:00', '20:00'), true);
    assert.equal(timesOverlap('09:00', '12:00', '12:00', '18:00'), false);
    assert.equal(timesOverlap('09:00', '18:00', '10:00', '11:00'), true);
    assert.equal(timesOverlap('22:00', '02:00', '01:00', '03:00'), true);
    assert.equal(timesOverlap('22:00', '02:00', '03:00', '05:00'), false);
  });

  it('detects date range overlap', () => {
    const a1 = new Date('2026-09-01');
    const a2 = new Date('2026-09-30');
    const b1 = new Date('2026-09-15');
    const b2 = new Date('2026-10-15');
    assert.equal(dateRangesOverlap(a1, a2, b1, b2), true);
    assert.equal(
      dateRangesOverlap(a1, a2, new Date('2026-10-01'), new Date('2026-10-31')),
      false,
    );
  });

  it('validates HH:mm clock values', () => {
    assert.equal(isValidHHMM('23:59'), true);
    assert.equal(isValidHHMM('24:00'), false);
    assert.equal(isValidHHMM('12:99'), false);
  });

  it('checks availability coverage for booking windows', () => {
    const availability = [{ weekdays: [1, 2, 3, 4, 5], startTime: '09:00', endTime: '18:00' }];
    assert.equal(
      availabilityCoversBooking(availability, {
        startDate: new Date('2026-09-07'),
        endDate: new Date('2026-09-07'),
        weekdays: [1],
        startTime: '10:00',
        endTime: '12:00',
      }),
      true,
    );
    assert.equal(
      availabilityCoversBooking(availability, {
        startDate: new Date('2026-09-07'),
        endDate: new Date('2026-09-07'),
        weekdays: [1],
        startTime: '08:00',
        endTime: '12:00',
      }),
      false,
    );
  });

  it('detects precise host block conflicts', () => {
    assert.equal(
      blockConflictsWithBooking(
        { startAt: new Date('2026-09-07T11:00:00Z'), endAt: new Date('2026-09-07T12:00:00Z') },
        {
          startDate: new Date('2026-09-07'),
          endDate: new Date('2026-09-07'),
          weekdays: [1],
          startTime: '10:00',
          endTime: '13:00',
        },
      ),
      true,
    );
  });
});

describe('commission', () => {
  it('takes 15 percent', () => {
    assert.equal(commission(10000), 1500);
  });
});
