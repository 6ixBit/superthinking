-- First, drop any existing policies that might be conflicting
DROP POLICY IF EXISTS "Users can upload to their own folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;
DROP POLICY IF EXISTS "Public can read files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload" ON storage.objects;

-- Since the bucket is public, let's create more permissive policies for the audio bucket

-- Allow authenticated users to upload to audio bucket (with user folder structure)
CREATE POLICY "Authenticated users can upload to audio bucket" 
ON storage.objects 
FOR INSERT 
TO authenticated 
WITH CHECK (
  bucket_id = 'audio'
);

-- Allow authenticated users to read from audio bucket
CREATE POLICY "Authenticated users can read from audio bucket" 
ON storage.objects 
FOR SELECT 
TO authenticated 
USING (
  bucket_id = 'audio'
);

-- Allow authenticated users to update their own files in audio bucket
CREATE POLICY "Authenticated users can update audio files" 
ON storage.objects 
FOR UPDATE 
TO authenticated 
USING (
  bucket_id = 'audio'
);

-- Allow authenticated users to delete their own files in audio bucket
CREATE POLICY "Authenticated users can delete audio files" 
ON storage.objects 
FOR DELETE 
TO authenticated 
USING (
  bucket_id = 'audio'
);

-- Also allow public read access since the bucket is public
CREATE POLICY "Public can read audio files" 
ON storage.objects 
FOR SELECT 
TO public 
USING (
  bucket_id = 'audio'
); 