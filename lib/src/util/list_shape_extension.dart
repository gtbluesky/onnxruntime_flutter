import 'dart:typed_data';

extension ListShape on List {
  /// Reshape list to a another [shape]
  ///
  /// [T] is the type of elements in list
  ///
  /// Returns List<dynamic> if [shape.length] > 5
  /// else returns list with exact type
  ///
  /// Throws [ArgumentError] if number of elements for [shape]
  /// mismatch with current number of elements in list
  List reshape<T>(List<int> shape) {
    var dims = shape.length;
    // var numElements = 1;
    // for (var i = 0; i < dims; i++) {
    //   numElements *= shape[i];
    // }

    if (dims <= 5) {
      switch (dims) {
        case 2:
          return _reshape2<T>(shape);
        case 3:
          return _reshape3<T>(shape);
        case 4:
          return _reshape4<T>(shape);
        case 5:
          return _reshape5<T>(shape);
      }
    }

    var reshapedList = flatten<dynamic>();

    /// dims > 5
    for (var i = dims - 1; i > 0; i--) {
      var temp = [];
      for (var start = 0;
          start + shape[i] <= reshapedList.length;
          start += shape[i]) {
        temp.add(reshapedList.sublist(start, start + shape[i]));
      }
      reshapedList = temp;
    }
    return reshapedList;
  }

  List<List<T>> _reshape2<T>(List<int> shape) {
    var flatList = flatten<T>();
    List<List<T>> reshapedList = List.generate(
      shape[0],
      (i) => List.generate(
        shape[1],
        (j) => flatList[i * shape[1] + j],
      ),
    );

    return reshapedList;
  }

  List<List<List<T>>> _reshape3<T>(List<int> shape) {
    if (shape.length != 3) {
      throw ArgumentError(
          "Shape must have exactly three dimensions for _reshape3.");
    }

    final flatList = flatten<T>();
    final dim0 = shape[0];
    final dim1 = shape[1];
    final dim2 = shape[2];

    if (flatList.length != dim0 * dim1 * dim2) {
      throw ArgumentError(
          "The size of the flat list does not match the provided shape.");
    }

    List<List<List<T>>> reshapedList = List.generate(dim0, (i) {
      final offset0 = i * dim1 * dim2;
      return List.generate(dim1, (j) {
        final offset1 = offset0 + j * dim2;
        return flatList.sublist(offset1, offset1 + dim2);
      });
    });

    return reshapedList;
  }

  List<List<List<List<T>>>> _reshape4<T>(List<int> shape) {
    var flatList = flatten<T>();

    List<List<List<List<T>>>> reshapedList = List.generate(
      shape[0],
      (i) => List.generate(
        shape[1],
        (j) => List.generate(
          shape[2],
          (k) => List.generate(
            shape[3],
            (l) => flatList[i * shape[1] * shape[2] * shape[3] +
                j * shape[2] * shape[3] +
                k * shape[3] +
                l],
          ),
        ),
      ),
    );

    return reshapedList;
  }

  List<List<List<List<List<T>>>>> _reshape5<T>(List<int> shape) {
    var flatList = flatten<T>();
    List<List<List<List<List<T>>>>> reshapedList = List.generate(
      shape[0],
      (i) => List.generate(
        shape[1],
        (j) => List.generate(
          shape[2],
          (k) => List.generate(
            shape[3],
            (l) => List.generate(
              shape[4],
              (m) => flatList[i * shape[1] * shape[2] * shape[3] * shape[4] +
                  j * shape[2] * shape[3] * shape[4] +
                  k * shape[3] * shape[4] +
                  l * shape[4] +
                  m],
            ),
          ),
        ),
      ),
    );

    return reshapedList;
  }

  /// Get shape of the list
  List<int> get shape {
    if (isEmpty) {
      return [];
    }
    var list = this as dynamic;
    var shape = <int>[];
    while (list is List) {
      shape.add(list.length);
      list = list.elementAt(0);
    }
    return shape;
  }

  /// Flatten this list, [T] is element type
  /// if not specified List<dynamic> is returned
  List<T> flatten<T>() {
    final flat = <T>[];
    final stack = <List>[this];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final item in current) {
        if (item is List) {
          stack.add(item);
        } else if (item is T) {
          flat.add(item);
        }
      }
    }
    return flat;
  }

  dynamic element() {
    var list = this as dynamic;
    while (list is List && !list.isByteBuffer()) {
      list = list.elementAt(0);
    }
    return list;
  }

  bool isByteBuffer() {
    if (this is Uint8List) {
      return true;
    }
    if (this is Int8List) {
      return true;
    }
    if (this is Uint16List) {
      return true;
    }
    if (this is Int16List) {
      return true;
    }
    if (this is Uint32List) {
      return true;
    }
    if (this is Int32List) {
      return true;
    }
    if (this is Uint64List) {
      return true;
    }
    if (this is Int64List) {
      return true;
    }
    if (this is Float32List) {
      return true;
    }
    if (this is Float64List) {
      return true;
    }
    return false;
  }
}
