import { QueryClientProvider } from "@tanstack/react-query";
import { queryClientInstance } from "@/lib/query-client";
import { BrowserRouter as Router, Route, Routes } from "react-router-dom";
import PageNotFound from "./lib/PageNotFound";
import ScrollToTop from "./components/ScrollToTop";
import Layout from "@/components/Layout";

// Pages
import Landing from "@/pages/Landing";
import Fleet from "@/pages/Fleet";
import Profiles from "@/pages/Profiles";
import Repos from "@/pages/Repos";
import AppSettings from "@/pages/AppSettings";

function App() {
  return (
    <QueryClientProvider client={queryClientInstance}>
      <Router basename="/os">
        <ScrollToTop />
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route element={<Layout />}>
            <Route path="/fleet" element={<Fleet />} />
            <Route path="/profiles" element={<Profiles />} />
            <Route path="/repos" element={<Repos />} />
            <Route path="/settings" element={<AppSettings />} />
          </Route>
          <Route path="*" element={<PageNotFound />} />
        </Routes>
      </Router>
    </QueryClientProvider>
  );
}

export default App;
