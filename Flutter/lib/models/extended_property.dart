import 'package:json_to_dart/utils/enums.dart';
import 'package:json_to_dart/utils/camel_under_score_converter.dart';
import 'package:json_to_dart/utils/dart_helper.dart';
import 'package:json_to_dart/utils/my_string_buffer.dart';
import 'package:json_to_dart/utils/string_helper.dart';
import 'config.dart';

class ExtendedProperty {
  final String uid;
  final int depth;
  final String key;
  final dynamic value;
  final MapEntry<String, dynamic> keyValuePair;
  String name;
  PropertyAccessorType propertyAccessorType = PropertyAccessorType.none;

  DartType type;

  ExtendedProperty({String uid, this.depth, this.keyValuePair})
      : key = keyValuePair.key,
        uid = uid + "_" + keyValuePair.key,
        value = keyValuePair.value,
        name = keyValuePair.key,
        propertyAccessorType = appConfig.propertyAccessorType,
        type = DartHelper.converDartType(keyValuePair.value.runtimeType);

  void updateNameByNamingConventionsType() {
    switch (appConfig.propertyNamingConventionsType) {
      case PropertyNamingConventionsType.none:
        this.name = name ?? key;
        break;
      case PropertyNamingConventionsType.camelCase:
        this.name = camelName(name ?? key);
        break;
      case PropertyNamingConventionsType.pascal:
        this.name = upcaseCamelName(name ?? key);
        break;
      case PropertyNamingConventionsType.hungarianNotation:
        this.name = underScoreName(name ?? key);
        break;
      default:
        this.name = name ?? key;
        break;
    }
  }

  void updatePropertyAccessorType() {
    propertyAccessorType = appConfig.propertyAccessorType;
  }

  String getTypeString({String className}) {
    var temp = value;
    String result;

    while (temp is List) {
      if (result == null) {
        result = "List<{0}>";
      } else {
        result = stringFormat("List<{0}>", <dynamic>[result]);
      }
      if (temp is List && temp.isNotEmpty) {
        temp = temp.first;
      } else {
        break;
      }
    }

    if (result != null) {
      result = stringFormat(result, <dynamic>[
        className ??
            DartHelper.getDartTypeString(
                DartHelper.converDartType(temp?.runtimeType ?? Object))
      ]);
    }

    return result ?? (className ?? DartHelper.getDartTypeString(type));
  }

  String getBaseTypeString({String className}) {
    if (className != null) return className;
    var temp = value;
    while (temp is List) {
      if (temp is List && temp.isNotEmpty) {
        temp = temp.first;
      } else {
        break;
      }
    }

    return DartHelper.getDartTypeString(DartHelper.converDartType(temp?.runtimeType ?? Object));
  }

  String getArraySetPropertyString(String setName, String typeString,
      {String className, String baseType}) {
    var temp = value;
    MyStringBuffer sb = new MyStringBuffer();
    sb.writeLine(
        " final  $typeString $setName = jsonRes['$key'] is List ? ${typeString.substring('List'.length)}[]: null; ");
    sb.writeLine("    if($setName!=null) {");
    bool enableTryCatch = appConfig.enableArrayProtection;
    int count = 0;
    String result;
    while (temp is List) {
      if (temp is List && temp.isNotEmpty) {
        temp = temp.first;
      } else {
        temp = null;
      }
      //删掉List<
      typeString = typeString.substring("List<".length);
      //删掉>
      typeString = typeString.substring(0, typeString.length - 1);

      ///下层为数组
      if (temp != null && temp is List) {
        if (count == 0) {
          result =
              " for (final dynamic item$count in asT<List<dynamic>>(jsonRes['$key'])) { if (item$count != null) {final $typeString items${count + 1} = ${typeString.substring('List'.length)}[]; {} $setName.add(items${count + 1}); }}";
        } else {
          result = result.replaceAll("{}",
              " for (final dynamic item$count in asT<List<dynamic>>(item${count - 1})) { if (item$count != null) {final $typeString items${count + 1} = ${typeString.substring('List'.length)}[]; {} items$count.add(items${count + 1}); }}");
        }
      }

      ///下层不为数组
      else {
        var item = ("item" + (count == 0 ? "" : count.toString()));
        var addString = "";
        if (className != null) {
          item = "$className.fromJson(asT<Map<String,dynamic>>($item))";
        } else {
          item = DartHelper.getUseAsT(baseType, item);
        }

        if (count == 0) {
          addString = "$setName.add($item); ";
          if (enableTryCatch) {
            addString = "tryCatch(() { $addString }); ";
          }

          result =
              " for (final dynamic item in jsonRes['$key']) { if (item != null) { $addString }}";
        } else {
          addString = "items$count.add($item); ";

          if (enableTryCatch) {
            addString = "tryCatch(() { $addString }); ";
          }

          result = result.replaceAll("{}",
              " for (final dynamic item$count in asT<List<dynamic>>(item${count - 1})) { if (item$count != null) {$addString}}");
        }
      }

      count++;
    }

    sb.writeLine(result);
    sb.writeLine("    }\n");

    return sb.toString();
  }
}
