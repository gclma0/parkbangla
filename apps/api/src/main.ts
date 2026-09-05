import 'dotenv/config';
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { AppModule } from './app.module';
import { createRateLimitMiddleware } from './rate-limit';
import { installProcessErrorLogging, requestLogger } from './request-logger';

async function bootstrap() {
  installProcessErrorLogging();
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.enableCors({ origin: true });
  app.use(requestLogger());
  app.use(createRateLimitMiddleware());
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.useStaticAssets(join(process.cwd(), 'uploads'), { prefix: '/uploads/' });
  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port, '0.0.0.0');
  console.log(JSON.stringify({ level: 'info', event: 'api_started', port, env: process.env.NODE_ENV ?? 'development' }));
}

bootstrap();
