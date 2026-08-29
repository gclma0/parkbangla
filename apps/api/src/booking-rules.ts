export function weekdayOverlap(a: number[], b: number[]) {
  return a.some((d) => b.includes(d));
}

export function toMinutes(hhmm: string) {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

export function timesOverlap(aStart: string, aEnd: string, bStart: string, bEnd: string) {
  const as = toMinutes(aStart);
  const ae = toMinutes(aEnd);
  const bs = toMinutes(bStart);
  const be = toMinutes(bEnd);
  return as < be && bs < ae;
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
  return (
    dateRangesOverlap(existing.startDate, existing.endDate, incoming.startDate, incoming.endDate) &&
    weekdayOverlap(existing.weekdays, incoming.weekdays) &&
    timesOverlap(existing.startTime, existing.endTime, incoming.startTime, incoming.endTime)
  );
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
