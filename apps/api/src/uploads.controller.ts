import { Controller, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
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
          const name = `${Date.now()}${extname(file.originalname) || '.jpg'}`;
          cb(null, name);
        },
      }),
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  upload(@UploadedFile() file: { filename: string }) {
    return { url: `/uploads/${file.filename}` };
  }
}
