export function weekdayOverlap(a: number[], b: number[]) {
  return a.some((d) => b.includes(d));
}

export function isValidHHMM(hhmm: string) {
  if (!/^\d{2}:\d{2}$/.test(hhmm)) return false;
  const [h, m] = hhmm.split(':').map(Number);
  return h >= 0 && h <= 23 && m >= 0 && m <= 59;
}

export function toMinutes(hhmm: string) {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

export function timesOverlap(aStart: string, aEnd: string, bStart: string, bEnd: string) {
  return minuteIntervals(aStart, aEnd).some(([as, ae]) =>
    minuteIntervals(bStart, bEnd).some(([bs, be]) => as < be && bs < ae),
  );
}

export function dateRangesOverlap(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date) {
  return aStart <= bEnd && bStart <= aEnd;
}

export function bookingsConflict(
  existing: {
    startDate: Date;
    endDate: Date;
    weekdays: number[];
    startTime: string;
    endTime: string;
  },
  incoming: {
    startDate: Date;
    endDate: Date;
    weekdays: number[];
    startTime: string;
    endTime: string;
  },
) {
  if (!dateRangesOverlap(existing.startDate, existing.endDate, incoming.startDate, incoming.endDate)) return false;
  return bookingIntervals(existing).some((a) => bookingIntervals(incoming).some((b) => intervalsOverlap(a, b)));
}

export type BookingWindow = {
  startDate: Date;
  endDate: Date;
  weekdays: number[];
  startTime: string;
  endTime: string;
};

export type AvailabilityWindow = {
  weekdays: number[];
  startTime: string;
  endTime: string;
};

export function minuteIntervals(startTime: string, endTime: string): [number, number][] {
  const start = toMinutes(startTime);
  const end = toMinutes(endTime);
  if (start === end) return [];
  if (start < end) return [[start, end]];
  return [
    [start, 24 * 60],
    [0, end],
  ];
}

export function dayStart(date: Date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

export function addDays(date: Date, days: number) {
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

export function dateAtMinutes(date: Date, minutes: number) {
  const result = dayStart(date);
  result.setUTCMinutes(minutes);
  return result;
}

export function bookingIntervals(window: BookingWindow): Array<[Date, Date]> {
  const intervals: Array<[Date, Date]> = [];
  for (let day = dayStart(window.startDate); day <= dayStart(window.endDate); day = addDays(day, 1)) {
    if (!window.weekdays.includes(day.getUTCDay())) continue;
    const start = dateAtMinutes(day, toMinutes(window.startTime));
    const endMinutes = toMinutes(window.endTime);
    const end = dateAtMinutes(window.endTime > window.startTime ? day : addDays(day, 1), endMinutes);
    intervals.push([start, end]);
  }
  return intervals;
}

export function intervalsOverlap(a: [Date, Date], b: [Date, Date]) {
  return a[0] < b[1] && b[0] < a[1];
}

export function blockConflictsWithBooking(block: { startAt: Date; endAt: Date }, booking: BookingWindow) {
  return bookingIntervals(booking).some((interval) => intervalsOverlap(interval, [block.startAt, block.endAt]));
}

export function availabilityCoversBooking(availability: AvailabilityWindow[], booking: BookingWindow) {
  const requested = bookingIntervals(booking);
  if (requested.length === 0 || availability.length === 0) return false;

  return requested.every(([start, end]) => {
    const startDay = dayStart(start);
    const startMinute = start.getUTCHours() * 60 + start.getUTCMinutes();
    const endMinute = end.getUTCHours() * 60 + end.getUTCMinutes();
    const crossesMidnight = dayStart(end).getTime() !== startDay.getTime();

    return availability.some((slot) => {
      if (!slot.weekdays.includes(startDay.getUTCDay())) return false;
      if (crossesMidnight && slot.endTime > slot.startTime) return false;
      if (!crossesMidnight && slot.endTime < slot.startTime) return false;
      const slotStart = toMinutes(slot.startTime);
      const slotEnd = toMinutes(slot.endTime);
      if (crossesMidnight) {
        return slotStart <= startMinute && slotEnd >= endMinute;
      }
      return slotStart <= startMinute && slotEnd >= endMinute;
    });
  });
}

export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function suggestedPrices(area: string) {
  const key = area.toLowerCase();
  if (key.includes('gulshan') || key.includes('banani')) {
    return { hourly: 80, daily: 500, monthly: 9000 };
  }
  if (key.includes('motijheel')) {
    return { hourly: 60, daily: 400, monthly: 7000 };
  }
  return { hourly: 50, daily: 350, monthly: 6000 };
}

export function commissionOn(amount: number, rate = Number(process.env.PLATFORM_COMMISSION ?? 0.15)) {
  return Math.round(amount * rate * 100) / 100;
}
