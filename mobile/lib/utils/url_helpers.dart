// lib/utils/url_helpers.dart
String cleanSupabaseUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  
  // Step 1: Remove all whitespace characters (spaces, newlines, tabs, etc.)
  url = url.replaceAll(RegExp(r'\s+'), '');
  
  // Step 2: Fix common typos - uppercase extensions
  url = url.replaceAll('.CO/', '.co/');
  url = url.replaceAll('.COM/', '.com/');
  
  // Step 3: Fix protocol if missing
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    if (url.contains('supabase.co')) {
      url = 'https://$url';
    }
  }
  
  // Step 4: Ensure proper URL structure
  // Fix any double slashes except after protocol
  url = url.replaceAll(RegExp(r'(?<!:)//+'), '/');
  
  // Step 5: Validate and fix the URL structure
  try {
    final uri = Uri.parse(url);
    
    // Rebuild URL with proper encoding
    if (uri.host.contains('supabase.co')) {
      // Extract path segments
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length >= 4 && 
          pathSegments[0] == 'storage' && 
          pathSegments[1] == 'v1' && 
          pathSegments[2] == 'object' && 
          pathSegments[3] == 'public') {
        
        // Rebuild URL with proper encoding for the file path
        final bucket = pathSegments[4];
        final filePath = pathSegments.skip(5).join('/');
        
        // Encode the file path properly
        final encodedPath = filePath.split('/').map((segment) {
          return Uri.encodeComponent(segment);
        }).join('/');
        
        return '${uri.scheme}://${uri.host}/storage/v1/object/public/$bucket/$encodedPath';
      }
    }
    
    return url;
  } catch (e) {
    print('Error parsing URL: $e');
    print('Original URL: $url');
    return url;
  }
}
