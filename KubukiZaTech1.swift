struct User {
    let name: String = "test"
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
    func sendRequest<T: RequestType>(_ request: T, completion: @escaping (Result<T.ResponseType>) -> Void) {
        Alamofire.request(request.URL,
              method: request.method,
              parameters: request.parameters,
              headers: request.headers).responseData { response in

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
}

struct GetUserRequest: RequestType {
    typealias ResponseType = User
    let id: String

    var path: String {
        return  "/v1/user/\(self.id)"
    }

    var method: HTTPMethod {
        return .get
    }

    func responseFromObject(_ object: Data) -> User? {
        return User(object)
    }
}

APIClient().sendRequest(GetUserRequest(id: "id")) { result in
    switch result {
    case .success(let user):
        /* success handler */
        break
    case .failure(let error):
        /* error handler */
        break
    }
}
