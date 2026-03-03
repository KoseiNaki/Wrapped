/**
 * Import Routes
 *
 * Endpoints for managing Spotify history imports.
 *
 * POST /imports           - Create a new import job
 * POST /imports/:id/upload - Upload file for import
 * GET  /imports/:id       - Get import status/progress
 * GET  /imports           - List user's imports
 */

import { Router, Response } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { v4 as uuidv4 } from 'uuid';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth';
import * as importService from '../services/importService';

const router = Router();

// Configure multer for file uploads
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, '../../uploads');

// Ensure upload directory exists
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, UPLOAD_DIR);
  },
  filename: (_req, file, cb) => {
    const uniqueName = `${uuidv4()}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 500 * 1024 * 1024, // 500MB max
  },
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ext === '.zip' || ext === '.json') {
      cb(null, true);
    } else {
      cb(new Error('Only .zip and .json files are allowed'));
    }
  },
});

/**
 * POST /imports
 *
 * Create a new import job. Returns import_id for subsequent upload.
 */
router.post('/', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.userId!;
    const { filename } = req.body || {};

    const importJob = await importService.createImport(userId, filename);

    res.status(201).json({
      import_id: importJob.id,
      status: importJob.status,
      upload_url: `/imports/${importJob.id}/upload`,
      created_at: importJob.created_at,
    });
  } catch (error) {
    console.error('Error creating import:', error);
    res.status(500).json({
      error: 'InternalError',
      message: 'Failed to create import job',
    });
  }
});

/**
 * POST /imports/:id/upload
 *
 * Upload a file for an existing import job.
 * Accepts multipart/form-data with a 'file' field.
 */
router.post(
  '/:id/upload',
  requireAuth,
  upload.single('file'),
  async (req: AuthenticatedRequest, res: Response) => {
    const importId = req.params.id;
    const userId = req.userId!;

    try {
      // Verify the import belongs to the user
      const importJob = await importService.getImport(importId, userId);

      if (!importJob) {
        // Clean up uploaded file if exists
        if (req.file) {
          fs.unlinkSync(req.file.path);
        }
        res.status(404).json({
          error: 'NotFound',
          message: 'Import job not found',
        });
        return;
      }

      if (importJob.status !== 'created') {
        if (req.file) {
          fs.unlinkSync(req.file.path);
        }
        res.status(400).json({
          error: 'InvalidState',
          message: `Cannot upload to import in status: ${importJob.status}`,
        });
        return;
      }

      if (!req.file) {
        res.status(400).json({
          error: 'MissingFile',
          message: 'No file uploaded',
        });
        return;
      }

      const filePath = req.file.path;
      const isZip = req.file.originalname.toLowerCase().endsWith('.zip');

      // Update import with file info
      await importService.updateImport(importId, {
        status: 'uploading',
        original_filename: req.file.originalname,
        file_size_bytes: req.file.size,
      });

      // Start processing in background (fire and forget)
      // This returns immediately and processes asynchronously
      setImmediate(() => {
        importService.startImportProcessing(filePath, userId, importId, isZip)
          .catch(err => console.error('Background processing error:', err));
      });

      // Return immediately with processing status
      res.status(202).json({
        import_id: importId,
        status: 'processing',
        message: 'File uploaded successfully. Processing started.',
        check_status_url: `/imports/${importId}`,
      });

    } catch (error) {
      // Clean up uploaded file on error
      if (req.file && fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }

      if (error instanceof multer.MulterError) {
        if (error.code === 'LIMIT_FILE_SIZE') {
          res.status(413).json({
            error: 'FileTooLarge',
            message: 'File size exceeds 500MB limit',
          });
          return;
        }
      }

      console.error('Error uploading file:', error);
      res.status(500).json({
        error: 'InternalError',
        message: error instanceof Error ? error.message : 'Failed to upload file',
      });
    }
  }
);

/**
 * GET /imports/:id
 *
 * Get import status and progress.
 */
router.get('/:id', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const importId = req.params.id;
    const userId = req.userId!;

    const importJob = await importService.getImport(importId, userId);

    if (!importJob) {
      res.status(404).json({
        error: 'NotFound',
        message: 'Import job not found',
      });
      return;
    }

    // Calculate progress percentage
    let progress = 0;
    if (importJob.status === 'complete') {
      progress = 100;
    } else if (importJob.total_files > 0) {
      progress = Math.round((importJob.processed_files / importJob.total_files) * 100);
    }

    res.json({
      id: importJob.id,
      status: importJob.status,
      source: importJob.source,
      original_filename: importJob.original_filename,
      file_size_bytes: importJob.file_size_bytes,
      progress: {
        percentage: progress,
        total_files: importJob.total_files,
        processed_files: importJob.processed_files,
        total_rows_seen: importJob.total_rows_seen,
        rows_inserted: importJob.rows_inserted,
        rows_deduped: importJob.rows_deduped,
      },
      error_message: importJob.error_message,
      created_at: importJob.created_at,
      started_at: importJob.started_at,
      finished_at: importJob.finished_at,
    });
  } catch (error) {
    console.error('Error getting import:', error);
    res.status(500).json({
      error: 'InternalError',
      message: 'Failed to get import status',
    });
  }
});

/**
 * GET /imports
 *
 * List all imports for the authenticated user.
 */
router.get('/', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.userId!;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);
    const offset = parseInt(req.query.offset as string) || 0;

    const imports = await importService.listImports(userId, limit, offset);
    const stats = await importService.getImportStats(userId);

    res.json({
      imports: imports.map(imp => ({
        id: imp.id,
        status: imp.status,
        original_filename: imp.original_filename,
        rows_inserted: imp.rows_inserted,
        rows_deduped: imp.rows_deduped,
        created_at: imp.created_at,
        finished_at: imp.finished_at,
      })),
      total_imports: stats.totalImports,
      total_events_imported: stats.totalEventsImported,
      last_import_at: stats.lastImportAt,
    });
  } catch (error) {
    console.error('Error listing imports:', error);
    res.status(500).json({
      error: 'InternalError',
      message: 'Failed to list imports',
    });
  }
});

/**
 * DELETE /imports/:id
 *
 * Delete an import and its associated events.
 */
router.delete('/:id', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const importId = req.params.id;
    const userId = req.userId!;

    const importJob = await importService.getImport(importId, userId);

    if (!importJob) {
      res.status(404).json({
        error: 'NotFound',
        message: 'Import job not found',
      });
      return;
    }

    // Prevent deleting in-progress imports
    if (importJob.status === 'processing' || importJob.status === 'uploading') {
      res.status(400).json({
        error: 'InvalidState',
        message: 'Cannot delete import while processing',
      });
      return;
    }

    // Delete import (cascade deletes events due to FK constraint)
    const { query } = await import('../config/database');
    await query('DELETE FROM imports WHERE id = $1 AND user_id = $2', [importId, userId]);

    res.status(204).send();
  } catch (error) {
    console.error('Error deleting import:', error);
    res.status(500).json({
      error: 'InternalError',
      message: 'Failed to delete import',
    });
  }
});

export default router;
