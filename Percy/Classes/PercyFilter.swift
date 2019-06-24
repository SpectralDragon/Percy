//
//  PercyFilter.swift
//  Percy
//
//  Created by v.a.prusakov on 24/06/2019.
//

import Foundation
import CoreData

public protocol Filter: CustomStringConvertible {
    associatedtype Entity
    func filter(_ isIncluded: Entity, object: NSManagedObject) -> Bool
}

public struct AnyFilter<T: Persistable>: Filter {
    
    private let filter: (T, NSManagedObject) -> Bool
    private let _description: () -> String
    
    public init<F: Filter>(_ filter: F) where F.Entity == T {
        self.filter = { filter.filter($0, object: $1) }
        self._description = { filter.description }
    }
    
    public func filter(_ isIncluded: T, object: NSManagedObject) -> Bool {
        return self.filter(isIncluded, object)
    }
    
    public var description: String {
        return _description()
    }
}

public class PredicateFilter<T: Persistable>: Filter {
    
    private let predicate: NSPredicate
    
    public init(predicate: NSPredicate) {
        self.predicate = predicate
    }
    
    public func filter(_ isIncluded: T, object: NSManagedObject) -> Bool {
        return predicate.evaluate(with: object)
    }
    
    public var description: String {
        return "PredicateFilter(\(predicate.description))"
    }
}

public class EntityFilter<T: Persistable>: Filter {
    
    private let filterBlock: (T) -> Bool
    
    public init(_ filterBlock: @escaping (T) -> Bool) {
        self.filterBlock = filterBlock
    }
    
    public func filter(_ isIncluded: T, object: NSManagedObject) -> Bool {
        return filterBlock(isIncluded)
    }
    
    public var description: String {
        return "EntityFilter(Function)"
    }
    
}

public class CompoundFilter<T: Persistable>: Filter {
    
    enum Expression {
        case or([AnyFilter<T>]), and([AnyFilter<T>]), not(AnyFilter<T>)
        
        var description: String {
            switch self {
            case .and(let filters):
                return filters.reduce(String(), { self.reduce(r: $0, f: $1, expression: "AND") })
            case .or(let filters):
                return filters.reduce(String(), { self.reduce(r: $0, f: $1, expression: "OR") })
            case .not(let filter):
                return "NOT \(filter.description)"
            }
        }
        
        private func reduce(r: String, f: AnyFilter<T>, expression: String) -> String {
            if r.isEmpty {
                return f.description
            }
            
            return r + " \(expression) " + f.description
        }
    }
    
    private let subfilters: Expression
    
    public init<F: Filter>(andFilterWithSubfilters subfilters: [F]) where F.Entity == T {
        self.subfilters = .and(subfilters.map { AnyFilter($0) })
    }
    
    public init<F: Filter>(orFilterWithSubfilters subfilters: [F]) where F.Entity == T {
        self.subfilters = .or(subfilters.map { AnyFilter($0) })
    }
    
    public init<F: Filter>(notFilterWithSubfilter subfilter: F) where F.Entity == T {
        self.subfilters = .not(AnyFilter(subfilter))
    }
    
    public func filter(_ isIncluded: T, object: NSManagedObject) -> Bool {
        switch subfilters {
        case .or(let filters):
            
            var result = false
            
            for filter in filters {
                let currentFilterResult = filter.filter(isIncluded, object: object)
                if result || currentFilterResult {
                    return true
                } else {
                    result = currentFilterResult
                }
            }
            
            return result
        case .and(let filters):
            
            var result = true
            
            for filter in filters {
                let currentFilterResult = filter.filter(isIncluded, object: object)
                
                if result && currentFilterResult {
                    result = currentFilterResult
                } else {
                    return false
                }
            }
            
            return result
        case .not(let filter):
            return !filter.filter(isIncluded, object: object)
        }
    }
    
    public var description: String {
        return self.subfilters.description
    }
    
}
