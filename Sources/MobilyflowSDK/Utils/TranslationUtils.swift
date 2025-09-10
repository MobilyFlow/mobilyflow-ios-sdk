//
//  TranslationUtils.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 04/09/2025.
//

func getTranslationValue(_ translations: [[String: Any]], field: String) -> String? {
    for translation in translations {
        if (translation["field"] as! String) == field {
            return translation["value"] as? String
        }
    }
    return nil
}
