import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  final databaseUrl = Platform.environment['DATABASE_URL'];

  final conn = PostgreSQLConnection.fromUri(databaseUrl!);
  await conn.open();

  final router = Router();

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

  router.get('/users', (Request request) async {
    final result = await conn.query('SELECT * FROM users');

    return Response.ok(
      jsonEncode(result),
      headers: {'Content-Type': 'application/json'},
    );
  });

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(router);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  await io.serve(handler, '0.0.0.0', port);
}
