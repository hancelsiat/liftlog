String cleanSupabaseUrl(String url) {
  // Remove newlines + trim spaces
  url = url.replaceAll('\n', '').trim();

  // Remove random spaces around slashes
  url = url.replaceAll(' /', '/').replaceAll('/ ', '/');

  // Fix "co /storage" → "co/storage"
  url = url.replaceAll('.co /', '.co/');

  // Fix triple spaces
  url = url.replaceAll(RegExp(r'\s+'), '');

  // If URL starts with '/storage', prepend the Supabase host
  if (url.startsWith('/storage')) {
    url = 'https://biygdnkxgnrynkjlecen.supabase.co$url';
  }

  // Now re-encode only the PATH portion
  final reg = RegExp(r'(/storage/v1/object/public/[^/]+/)(.+)$');
  final m = reg.firstMatch(url);
  if (m != null) {
    final prefix = m.group(1)!;
    final path = m.group(2)!;
    return prefix + Uri.encodeComponent(path);
  }

  return url;
}
