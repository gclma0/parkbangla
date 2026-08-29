import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { timesOverlap, weekdayOverlap, dateRangesOverlap } from './booking-rules';

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
});

describe('commission', () => {
  it('takes 15 percent', () => {
    assert.equal(commission(10000), 1500);
  });
});
