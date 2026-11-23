import http from "node:http";

const port = Number(process.env.PORT || 3000);

const server = http.createServer((request, response) => {
  if (request.url === "/health" || request.url === "/") {
    response.writeHead(200, { "Content-Type": "application/json" });
    response.end(JSON.stringify({ status: "ok", app: "Zombie Apocalypse: Ranger Outbreak" }));
    return;
  }

  response.writeHead(404, { "Content-Type": "application/json" });
  response.end(JSON.stringify({ status: "not_found" }));
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Healthcheck server listening on port ${port}`);
});
