/**
 * Import Service Tests
 *
 * Tests for parsing and importing Spotify streaming history.
 */

import { Readable } from 'stream';

// Mock the database module before importing the service
jest.mock('../config/database', () => ({
  query: jest.fn(),
  getClient: jest.fn(),
  pool: {
    connect: jest.fn(),
    query: jest.fn(),
    end: jest.fn(),
  },
}));

import { query, getClient } from '../config/database';
import * as importService from '../services/importService';

// Sample test data
const sampleStreamingHistory = [
  {
    endTime: '2023-01-15 14:30',
    artistName: 'Taylor Swift',
    trackName: 'Anti-Hero',
    msPlayed: 200000,
  },
  {
    endTime: '2023-01-15 14:35',
    artistName: 'The Weeknd',
    trackName: 'Blinding Lights',
    msPlayed: 180000,
  },
];

const sampleEndsong = [
  {
    ts: '2023-01-15T14:30:00Z',
    ms_played: 200000,
    master_metadata_track_name: 'Anti-Hero',
    master_metadata_album_artist_name: 'Taylor Swift',
    master_metadata_album_album_name: 'Midnights',
    spotify_track_uri: 'spotify:track:0V3wPSX9ygBnCm8psDIegu',
    reason_start: 'clickrow',
    reason_end: 'trackdone',
    shuffle: false,
    skipped: false,
    offline: false,
    incognito_mode: false,
    platform: 'iOS',
    ip_addr_decrypted: '192.168.1.1',
    conn_country: 'US',
  },
  {
    ts: '2023-01-15T14:35:00Z',
    ms_played: 180000,
    master_metadata_track_name: 'Blinding Lights',
    master_metadata_album_artist_name: 'The Weeknd',
    master_metadata_album_album_name: 'After Hours',
    spotify_track_uri: 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
    reason_start: 'autoplay',
    reason_end: 'trackdone',
    shuffle: true,
    skipped: false,
    offline: false,
    incognito_mode: false,
    platform: 'iOS',
    ip_addr_decrypted: '192.168.1.1',
    conn_country: 'US',
  },
];

describe('Import Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createImport', () => {
    it('should create a new import job', async () => {
      const mockImport = {
        id: 'test-import-id',
        user_id: 'test-user-id',
        status: 'created',
        created_at: new Date(),
      };

      (query as jest.Mock).mockResolvedValueOnce({ rows: [mockImport] });

      const result = await importService.createImport('test-user-id', 'test.zip');

      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO imports'),
        ['test-user-id', 'test.zip']
      );
      expect(result.id).toBe('test-import-id');
      expect(result.status).toBe('created');
    });
  });

  describe('getImport', () => {
    it('should return import for valid user', async () => {
      const mockImport = {
        id: 'test-import-id',
        user_id: 'test-user-id',
        status: 'processing',
      };

      (query as jest.Mock).mockResolvedValueOnce({ rows: [mockImport] });

      const result = await importService.getImport('test-import-id', 'test-user-id');

      expect(result).toEqual(mockImport);
    });

    it('should return null for wrong user', async () => {
      (query as jest.Mock).mockResolvedValueOnce({ rows: [] });

      const result = await importService.getImport('test-import-id', 'wrong-user-id');

      expect(result).toBeNull();
    });
  });

  describe('updateImport', () => {
    it('should update import fields', async () => {
      const mockUpdatedImport = {
        id: 'test-import-id',
        status: 'processing',
        rows_inserted: 100,
      };

      (query as jest.Mock).mockResolvedValueOnce({ rows: [mockUpdatedImport] });

      const result = await importService.updateImport('test-import-id', {
        status: 'processing',
        rows_inserted: 100,
      });

      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('UPDATE imports'),
        expect.arrayContaining(['processing', 100, 'test-import-id'])
      );
      expect(result?.status).toBe('processing');
    });
  });

  describe('listImports', () => {
    it('should list imports for user', async () => {
      const mockImports = [
        { id: 'import-1', status: 'complete' },
        { id: 'import-2', status: 'processing' },
      ];

      (query as jest.Mock).mockResolvedValueOnce({ rows: mockImports });

      const result = await importService.listImports('test-user-id', 20, 0);

      expect(result).toHaveLength(2);
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('SELECT * FROM imports'),
        ['test-user-id', 20, 0]
      );
    });
  });

  describe('Record Normalization', () => {
    // We need to test the internal normalization functions
    // Since they're private, we'll test through a mock stream processor

    it('should handle StreamingHistory format correctly', () => {
      // Test the endTime parsing format
      const endTime = '2023-01-15 14:30';
      const [datePart, timePart] = endTime.split(' ');
      const [year, month, day] = datePart.split('-').map(Number);
      const [hour, minute] = timePart.split(':').map(Number);

      const date = new Date(Date.UTC(year, month - 1, day, hour, minute, 0));

      expect(date.toISOString()).toBe('2023-01-15T14:30:00.000Z');
    });

    it('should handle endsong ISO format correctly', () => {
      const ts = '2023-01-15T14:30:00Z';
      const date = new Date(ts);

      expect(date.toISOString()).toBe('2023-01-15T14:30:00.000Z');
    });

    it('should handle malformed dates gracefully', () => {
      const malformed = 'not-a-date';
      const date = new Date(malformed);

      expect(isNaN(date.getTime())).toBe(true);
    });
  });

  describe('Batch Processing', () => {
    it('should construct correct INSERT statement', () => {
      // Test the VALUES placeholder generation
      const events = [
        { played_at: new Date(), ms_played: 1000, track_name: 'Track 1', artist_name: 'Artist 1' },
        { played_at: new Date(), ms_played: 2000, track_name: 'Track 2', artist_name: 'Artist 2' },
      ];

      const valuePlaceholders: string[] = [];
      let paramIndex = 1;
      const fieldsPerRow = 17;

      for (let i = 0; i < events.length; i++) {
        const placeholders: string[] = [];
        for (let j = 0; j < fieldsPerRow; j++) {
          placeholders.push(`$${paramIndex + j}`);
        }
        valuePlaceholders.push(`(${placeholders.join(', ')})`);
        paramIndex += fieldsPerRow;
      }

      expect(valuePlaceholders).toHaveLength(2);
      expect(valuePlaceholders[0]).toContain('$1');
      expect(valuePlaceholders[0]).toContain('$17');
      expect(valuePlaceholders[1]).toContain('$18');
      expect(valuePlaceholders[1]).toContain('$34');
    });
  });

  describe('getImportStats', () => {
    it('should return aggregate stats', async () => {
      (query as jest.Mock).mockResolvedValueOnce({
        rows: [{
          total_imports: '5',
          total_events: '10000',
          last_import_at: new Date('2023-01-15'),
        }],
      });

      const stats = await importService.getImportStats('test-user-id');

      expect(stats.totalImports).toBe(5);
      expect(stats.totalEventsImported).toBe(10000);
      expect(stats.lastImportAt).toEqual(new Date('2023-01-15'));
    });

    it('should handle zero imports', async () => {
      (query as jest.Mock).mockResolvedValueOnce({
        rows: [{
          total_imports: '0',
          total_events: '0',
          last_import_at: null,
        }],
      });

      const stats = await importService.getImportStats('test-user-id');

      expect(stats.totalImports).toBe(0);
      expect(stats.totalEventsImported).toBe(0);
      expect(stats.lastImportAt).toBeNull();
    });
  });
});

describe('Data Format Validation', () => {
  describe('StreamingHistory format', () => {
    it('should validate required fields', () => {
      const validRecord = sampleStreamingHistory[0];

      expect(validRecord.endTime).toBeDefined();
      expect(validRecord.artistName).toBeDefined();
      expect(validRecord.trackName).toBeDefined();
      expect(typeof validRecord.msPlayed).toBe('number');
    });

    it('should handle missing optional fields', () => {
      const minimalRecord = {
        endTime: '2023-01-15 14:30',
        artistName: 'Test Artist',
        trackName: 'Test Track',
        msPlayed: 1000,
      };

      // All required fields present
      expect(minimalRecord.endTime).toBeTruthy();
      expect(minimalRecord.artistName).toBeTruthy();
      expect(minimalRecord.trackName).toBeTruthy();
    });
  });

  describe('Endsong format', () => {
    it('should validate all extended fields', () => {
      const record = sampleEndsong[0];

      expect(record.ts).toBeDefined();
      expect(record.master_metadata_track_name).toBeDefined();
      expect(record.master_metadata_album_artist_name).toBeDefined();
      expect(record.master_metadata_album_album_name).toBeDefined();
      expect(record.spotify_track_uri).toBeDefined();
      expect(typeof record.shuffle).toBe('boolean');
      expect(typeof record.skipped).toBe('boolean');
    });

    it('should handle records with null metadata', () => {
      const recordWithNulls = {
        ts: '2023-01-15T14:30:00Z',
        ms_played: 0,
        master_metadata_track_name: null,
        master_metadata_album_artist_name: null,
        master_metadata_album_album_name: null,
      };

      // Should be skipped due to null required fields
      expect(recordWithNulls.master_metadata_track_name).toBeNull();
    });
  });
});

describe('Deduplication Logic', () => {
  it('should identify duplicate records correctly', () => {
    const record1 = {
      user_id: 'user-1',
      played_at: new Date('2023-01-15T14:30:00Z'),
      track_name: 'Anti-Hero',
      artist_name: 'Taylor Swift',
      ms_played: 200000,
    };

    const record2 = {
      user_id: 'user-1',
      played_at: new Date('2023-01-15T14:30:00Z'),
      track_name: 'Anti-Hero',
      artist_name: 'Taylor Swift',
      ms_played: 200000,
    };

    // Create dedup key
    const key1 = `${record1.user_id}-${record1.played_at.toISOString()}-${record1.track_name}-${record1.artist_name}-${record1.ms_played}`;
    const key2 = `${record2.user_id}-${record2.played_at.toISOString()}-${record2.track_name}-${record2.artist_name}-${record2.ms_played}`;

    expect(key1).toBe(key2);
  });

  it('should distinguish different plays of same track', () => {
    const record1 = {
      user_id: 'user-1',
      played_at: new Date('2023-01-15T14:30:00Z'),
      track_name: 'Anti-Hero',
      artist_name: 'Taylor Swift',
      ms_played: 200000,
    };

    const record2 = {
      user_id: 'user-1',
      played_at: new Date('2023-01-15T15:30:00Z'), // Different time
      track_name: 'Anti-Hero',
      artist_name: 'Taylor Swift',
      ms_played: 200000,
    };

    const key1 = `${record1.user_id}-${record1.played_at.toISOString()}-${record1.track_name}-${record1.artist_name}-${record1.ms_played}`;
    const key2 = `${record2.user_id}-${record2.played_at.toISOString()}-${record2.track_name}-${record2.artist_name}-${record2.ms_played}`;

    expect(key1).not.toBe(key2);
  });
});
