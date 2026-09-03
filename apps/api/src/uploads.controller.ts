import { BadRequestException, Controller, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { mkdirSync } from 'fs';
import { AuthGuard } from './auth.guard';

const dest = join(process.cwd(), 'uploads');
mkdirSync(dest, { recursive: true });

@Controller()
@UseGuards(AuthGuard)
export class UploadsController {
  @Post('uploads')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: dest,
        filename: (_req, file, cb) => {
          const ext = extname(file.originalname).toLowerCase() || '.jpg';
          const name = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
          cb(null, name);
        },
      }),
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        const allowed = new Set(['image/jpeg', 'image/png', 'image/webp', 'application/pdf']);
        cb(null, allowed.has(file.mimetype));
      },
    }),
  )
  upload(@UploadedFile() file?: { filename: string }) {
    if (!file) throw new BadRequestException('Only JPEG, PNG, WebP, or PDF files up to 5 MB are allowed.');
    return { url: `/uploads/${file.filename}` };
  }
}
