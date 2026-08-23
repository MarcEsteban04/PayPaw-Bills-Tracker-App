import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The initialised Supabase client.
///
/// `Supabase.initialize()` runs in `main()`, and only when credentials were
/// supplied at build time — see `AppConfig`. Until the Supabase project exists
/// there are no credentials, so reading this provider throws. That is
/// intentional: every data source depends on this provider, which makes a
/// missing backend fail loudly at the boundary instead of producing empty
/// screens with no explanation.
final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) => Supabase.instance.client);
