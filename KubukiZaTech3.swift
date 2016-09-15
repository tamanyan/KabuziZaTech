class CacheManger {
    static let shared = CacheManger()
    func fetch(_ id: String) -> Any? {
        return nil
    }
}

protocol RequestCacheable {
    associatedtype ResponseType

    /**
     *  キャッシュ有効フラグ
     */
    var cacheEnabled: Bool { get set }


    /**
     *  キャッシュが存在する場合、ResponseTypeを返す
     */
    func cache() -> ResponseType?
}

protocol RequestRetryable {
    /**
     * リトライする回数
     */
    var retryCount: Int { get }

    /**
     * リトライするかどうかを判定する
     */
    func canRetry(error: Error) -> Bool
}

extension RequestRetryable {
    var retryCount: Int { return 3 }
}

struct KeywordList {
    let count = 0
    init(_ object: Data) { }
}

protocol RequestType {
    associatedtype ResponseType
    var baseURL: String { get }
    var method: HTTPMethod { get }
    var path: String { get }
    var parameters: [String: AnyObject] { get }
    var headers: [String: String] { get }

    /* HTTPのResponse Bodyからオブジェクトを返す */
    func responseFromObject(_ object: Data) -> ResponseType?
}

extension RequestType {
    var baseURL: String { return "https://..." }
    var headers: [String: String] { return [:] }
    var parameters: [String: AnyObject] { return [:] }
    var URL: String { return self.baseURL + self.path }
}

class APIClient {
    private func performRetryableRequest<T: RequestType & RequestRetryable>(_ request: T, retryCounter: Int = 0,
        completion: @escaping (Result<T.ResponseType>) -> Void) {

        Alamofire.request(request.URL, method: request.method,
                parameters: request.parameters, headers: request.headers).responseData { response in

                switch response.result {
                case .success(let value):
                    guard let responseData = request.responseFromObject(value) else {
                        return completion(Result.failure(/* fail to parse error */))
                    }
                    return completion(Result.success(responseData))
                case .failure(let error):
                    if request.retryCount > retryCounter && request.canRetry(error: error) {
                        return self.performRetryableRequest(request,
                            retryCounter: retryCounter + 1,
                            completion: completion)
                    }
                    return completion(Result.failure(error))
                }
        }
    }

    private func performRequest<T: RequestType>(_ request: T, completion: @escaping (Result<T.ResponseType>) -> Void) {
        Alamofire.request(request.URL, method: request.method,
                parameters: request.parameters, headers: request.headers).responseData { response in

                switch response.result {
                case .success(let value):
                    guard let responseData = request.responseFromObject(value) else {
                        return completion(Result.failure(/* fail to parse error */))
                    }
                    return completion(Result.success(responseData))
                case .failure(let error):
                    return completion(Result.failure(error))
                }
        }
    }

    private func performCachedRequest<T: RequestType & RequestCacheable>(_ request: T) -> T.ResponseType? {
        guard request.cacheEnabled else {
            return nil
        }
        return request.cache()
    }

    func sendRequest<T: RequestType>(_ request: T, completion: @escaping (Result<T.ResponseType>) -> Void) {
        self.performRequest(request, completion: completion)
    }

    func sendRequest<T: RequestType & RequestCacheable>(_ request: T, completion: @escaping (Result<T.ResponseType>) -> Void) {
        if let data = self.performCachedRequest(request) {
           return completion(Result.success(data))
        }
        self.performRequest(request, completion: completion)
    }

    func sendRequest<T: RequestType & RequestRetryable>(_ request: T, completion: @escaping (Result<T.ResponseType>) -> Void) {
        self.performRetryableRequest(request, completion: completion)
    }

    func sendRequest<T: RequestType & RequestCacheable & RequestRetryable>(_ request: T, completion: @escaping (Result<T.ResponseType>) -> Void) {
        if let data = self.performCachedRequest(request) {
           return completion(Result.success(data))
        }
        self.performRetryableRequest(request, completion: completion)
    }
}

struct GetKeywordListRequest: RequestType, RequestCacheable, RequestRetryable {
    typealias ResponseType = KeywordList

    var cacheEnabled: Bool = false

    var retryCount: Int {
        return 4
    }

    var path: String {
        return  "/v1/keywords"
    }

    var method: HTTPMethod {
        return .get
    }

    func responseFromObject(_ object: Data) -> KeywordList? {
        return KeywordList(object)
    }

    func canRetry(error: Error) -> Bool {
        return /* conditions of retry */ ? true : false
    }

    func cache() -> KeywordList? {
        return CacheManger.shared.fetch("keywords") as? KeywordList
    }
}

APIClient().sendRequest(GetKeywordListRequest()) { result in
    switch result {
    case .success(let keywordList):
        /* success handler */
        break
    case .failure(let error):
        /* error handler */
        break
    }
}
