import 'package:dio/dio.dart';
import 'package:fincore/api/api_client.dart';
import 'package:fincore/models/category.dart';

class CategoriesApi {
  final ApiClient client;
  CategoriesApi(this.client);

  Future<List<Category>> list({String? appliesTo, bool includeArchived = false}) async {
    try {
      final qp = <String, dynamic>{};
      if (appliesTo != null) qp['applies_to'] = appliesTo;
      if (includeArchived) qp['include_archived'] = 1;

      final response = await client.dio.get<Map<String, dynamic>>(
        '/finance/categories',
        queryParameters: qp.isEmpty ? null : qp,
      );
      final data = (response.data!['data'] as List<dynamic>);
      return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  Future<Category> create({
    required String name,
    required String appliesTo, // 'income' | 'expense' | 'both'
    required String colorSlug,
    required String iconSlug,
  }) async {
    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        '/finance/categories',
        data: <String, String>{
          'name': name,
          'applies_to': appliesTo,
          'color_slug': colorSlug,
          'icon_slug': iconSlug,
        },
      );
      return Category.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  Future<Category> update(String id, Map<String, dynamic> fields) async {
    try {
      final response = await client.dio.patch<Map<String, dynamic>>(
        '/finance/categories/$id',
        data: fields,
      );
      return Category.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }

  /// Archivar (soft delete). El backend usa DELETE.
  Future<void> archive(String id) async {
    try {
      await client.dio.delete<dynamic>('/finance/categories/$id');
    } on DioException catch (e) {
      throw dioToDomainError(e);
    }
  }
}
