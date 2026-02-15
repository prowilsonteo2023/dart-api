import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';

void main() async {
  // Read DATABASE_URL from environment
  final databaseUrl = Platform.environment['DATABASE_URL']!;
  final uri = Uri.parse(databaseUrl);

  // Parse the connection details from Neon URL
  final conn = PostgreSQLConnection(
    uri.host,
    uri.port == 0 ? 5432 : uri.port,
    uri.pathSegments.first,
    username: uri.userInfo.split(':')[0],
    password: uri.userInfo.split(':')[1],
    useSSL: true, // Neon requires SSL
  );

  await conn.open();
  print('✅ Connected to Neon PostgreSQL!');

  final router = Router();

  // POST /users -> create a user
  router.post('/users', (Request request) async {
    final body = jsonDecode(await request.readAsString());
    await conn.query(
      'INSERT INTO users (name, email) VALUES (@name, @email)',
      substitutionValues: {
        'name': body['name'],
        'email': body['email'],
      },
    );
    return Response.ok('User created');
  });

  // GET /users -> list all users
  router.get('/users', (Request request) async {
    final result = await conn.query('SELECT * FROM users');

    // Convert PostgreSQL result to JSON
    final users = result
        .map((row) => {
              'id': row[0],
              'name': row[1],
              'email': row[2],
            })
        .toList();

    return Response.ok(jsonEncode(users),
        headers: {'Content-Type': 'application/json'});
  });

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(router);

  // Render requires binding to PORT environment variable
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  await io.serve(handler, '0.0.0.0', port);
  print('🚀 Server running on port $port');
}
