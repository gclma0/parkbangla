import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
  ForbiddenException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from './prisma.service';

function isHostRoute(req: any): boolean {
  const path = req.path || req.url || '';
  const method = req.method;

  if (path.includes('/me/spots')) return true;
  if (path.includes('/spots') && method === 'POST' && !path.includes('/suggest-price')) return true;
  if (path.startsWith('/spots/') && (method === 'PATCH' || path.includes('/availability') || path.includes('/blocks'))) return true;
  if (path.startsWith('/bookings/') && path.endsWith('/decide')) return true;
  if (path.includes('/bookings') && req.query?.role === 'host') return true;
  if (path.includes('/wallet/withdraw')) return true;

  return false;
}

function isRenterRoute(req: any): boolean {
  const path = req.path || req.url || '';
  const method = req.method;

  if (path.includes('/bookings/commuter-pass') || path.includes('/bookings/instant')) return true;
  if (path.startsWith('/bookings/') && (path.endsWith('/reviews') || path.endsWith('/disputes'))) return true;
  if (path.includes('/spots') && method === 'GET' && !path.includes('/me/spots') && !path.includes('/suggest-price')) return true;
  if (path.startsWith('/spots/') && method === 'GET') return true;
  if (path.includes('/me/vehicles')) return true;

  return false;
}

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private jwt: JwtService,
    private prisma: PrismaService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    const header = req.headers.authorization as string | undefined;
    if (!header?.startsWith('Bearer ')) throw new UnauthorizedException();
    try {
      const payload = await this.jwt.verifyAsync(header.slice(7));
      const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) throw new UnauthorizedException();
      req.user = user;

      // Role check
      const activeRole = req.headers['x-active-role'] as string | undefined;
      const role = activeRole || 'renter';

      // Mock account role rules
      if (user.phone === '01710000001' && role !== 'renter') {
        throw new ForbiddenException('Mock renter is restricted to renter role only');
      }
      if ((user.phone === '01710000002' || user.phone === '01710000003') && role !== 'host') {
        throw new ForbiddenException('Mock host is restricted to host role only');
      }

      // Endpoint rules
      if (role === 'renter' && isHostRoute(req)) {
        throw new ForbiddenException('Access denied: Renter cannot access host features');
      }
      if (role === 'host' && isRenterRoute(req)) {
        throw new ForbiddenException('Access denied: Host cannot access renter features');
      }

      return true;
    } catch (e) {
      if (e instanceof ForbiddenException) throw e;
      throw new UnauthorizedException();
    }
  }
}
