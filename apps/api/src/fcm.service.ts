import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from './prisma.service';
import * as admin from 'firebase-admin';

@Injectable()
export class FcmService {
  private readonly logger = new Logger(FcmService.name);
  private initialized = false;

  constructor(private prisma: PrismaService) {
    this.initFirebase();
  }

  private initFirebase() {
    try {
      const saKey = process.env.FIREBASE_SERVICE_ACCOUNT;
      if (saKey) {
        let credential;
        if (saKey.trim().startsWith('{')) {
          credential = admin.credential.cert(JSON.parse(saKey));
        } else {
          credential = admin.credential.cert(saKey);
        }
        admin.initializeApp({ credential });
        this.initialized = true;
        this.logger.log('Firebase Admin SDK initialized successfully.');
      } else {
        this.logger.warn('FIREBASE_SERVICE_ACCOUNT env variable not found. FCM delivery will be simulated.');
      }
    } catch (e) {
      this.logger.error('Error initializing Firebase Admin SDK:', e);
    }
  }

  async sendNotification(params: {
    userId: string;
    title: string;
    body: string;
    bookingId?: string;
    type?: string;
  }) {
    // 1. Persist notification in database first
    const notification = await this.prisma.notification.create({
      data: {
        userId: params.userId,
        title: params.title,
        body: params.body,
        bookingId: params.bookingId,
        type: params.type,
      },
    });

    // 2. Fetch the user's fcmToken
    const user = await this.prisma.user.findUnique({
      where: { id: params.userId },
      select: { fcmToken: true },
    });

    if (!user?.fcmToken) {
      this.logger.log(`No FCM token found for user ${params.userId}. Persisted only.`);
      return notification;
    }

    // 3. Deliver FCM
    if (this.initialized) {
      try {
        const payload: admin.messaging.Message = {
          token: user.fcmToken,
          notification: {
            title: params.title,
            body: params.body,
          },
          data: params.bookingId ? { bookingId: params.bookingId } : {},
          android: {
            notification: {
              clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
        };
        await admin.messaging().send(payload);
        this.logger.log(`FCM successfully sent to user ${params.userId}`);
      } catch (e) {
        this.logger.error(`Failed to send FCM to user ${params.userId}:`, e);
      }
    } else {
      this.logger.log(`[SIMULATED FCM] To: ${params.userId} (${user.fcmToken}) | Title: ${params.title} | Body: ${params.body} | Data: ${params.bookingId ? `bookingId=${params.bookingId}` : 'none'}`);
    }

    return notification;
  }
}
