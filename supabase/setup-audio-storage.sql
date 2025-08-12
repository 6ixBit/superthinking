-- Create the audio storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, avif_autodetection, created_at, updated_at)
VALUES (
  'audio', 
  'audio', 
  true, 
  52428800, -- 50MB limit
  ARRAY['audio/mp4', 'audio/mpeg', 'audio/m4a', 'audio/aac', 'audio/wav', 'audio/x-m4a'], 
  false, 
  NOW(), 
  NOW()
) ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types,
  updated_at = NOW();

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Create RLS policy: Users can only upload to their own folder
CREATE POLICY "Users can upload to their own folder" 
ON storage.objects 
FOR INSERT 
TO authenticated 
WITH CHECK (
  bucket_id = 'audio' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Create RLS policy: Users can read their own files
CREATE POLICY "Users can read their own files" 
ON storage.objects 
FOR SELECT 
TO authenticated 
USING (
  bucket_id = 'audio' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Create RLS policy: Users can update their own files
CREATE POLICY "Users can update their own files" 
ON storage.objects 
FOR UPDATE 
TO authenticated 
USING (
  bucket_id = 'audio' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Create RLS policy: Users can delete their own files
CREATE POLICY "Users can delete their own files" 
ON storage.objects 
FOR DELETE 
TO authenticated 
USING (
  bucket_id = 'audio' 
  AND auth.uid()::text = (storage.foldername(name))[1]
); 