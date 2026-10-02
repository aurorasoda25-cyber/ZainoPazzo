class Materia {
  final int id;
  final String nome;

  Materia({required this.id, required this.nome});

  factory Materia.fromJson(Map<String, dynamic> json) {
    return Materia(
      id: json['id'] as int,
      nome: json['nome'] as String,
    );
  }
}